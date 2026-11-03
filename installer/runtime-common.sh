#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Shared implementation. Sourcing this file does not download, build or install.
set -euo pipefail
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
export PIN_FILE="$REPO_DIR/pins.json"
CACHE="${CAELESTIA_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-pop-os}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/caelestia-pop-os"
JOBS="${CAELESTIA_JOBS:-2}"
log() { printf '\n==> %s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
pin() {
    python3 "$REPO_DIR/scripts/runtime-metadata.py" pin "$@"
}
QT_PREFIX="$(pin qt.prefix)"
WAYLAND_PREFIX="$(pin wayland.prefix)"
PRIVATE_RPATH="$QT_PREFIX/lib:$WAYLAND_PREFIX/lib:/usr/local/lib:\$ORIGIN:\$ORIGIN/../lib"

init_runtime() {
    [[ $EUID != 0 ]] || die 'Run as your normal user; sudo is used only for system installation.'
    [[ $(uname -m) == x86_64 ]] || die 'These pins support x86_64 only.'
    [[ $JOBS =~ ^[1-9][0-9]*$ ]] || die 'CAELESTIA_JOBS must be a positive integer.'
    [[ $CACHE == /* && $DATA == /* ]] || die 'Cache and XDG data paths must be absolute.'
    [[ ! -L $CACHE ]] || die 'The private build cache must not be a symlink.'
    umask 022
    mkdir -p "$CACHE" "$DATA"
    [[ -O $CACHE && -O $DATA ]] || die 'Cache/data directory is not owned by the invoking user.'
    mkdir -p "$CACHE"/{sources,builds,downloads,receipts,logs} "$DATA/bin"
    # Never reuse the old installer's dirty caches or ambient Python/Qt setup.
    export UV_CACHE_DIR="$CACHE/uv-cache" PIP_CACHE_DIR="$CACHE/pip-cache"
    export UV_PYTHON_INSTALL_DIR="$DATA/python" UV_TOOL_DIR="$DATA/uv-tools"
    export UV_PYTHON_BIN_DIR="$DATA/python/bin"
    export UV_TOOL_BIN_DIR="$DATA/bin"
    export PIPX_HOME="$DATA/pipx" PIPX_BIN_DIR="$DATA/bootstrap/bin"
    export PIPX_MAN_DIR="$DATA/bootstrap/man"
    export PATH="$DATA/bin:$PIPX_BIN_DIR:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
    unset LD_LIBRARY_PATH QML_IMPORT_PATH QML2_IMPORT_PATH PYTHONPATH PYTHONHOME
    export PKG_CONFIG_PATH="$WAYLAND_PREFIX/lib/pkgconfig:/usr/local/lib/x86_64-linux-gnu/pkgconfig:/usr/local/lib/pkgconfig"
    python3 "$REPO_DIR/scripts/runtime-metadata.py" validate
}

lock_runtime() {
    exec 9>"$CACHE/runtime.lock"
    flock -n 9 || die "Another Caelestia runtime operation is using $CACHE."
}

fetch_source() { # component [pins path, default sources.component]
    local name=$1 key=${2:-sources.$1} url revision dir
    url=$(pin "$key.url"); revision=$(pin "$key.commit")
    [[ $revision =~ ^[0-9a-f]{40}$ ]] || die "$name is not pinned to a full commit."
    dir="$CACHE/sources/$name-$revision"
    if [[ ! -e $dir ]]; then
        # An interrupted clone remains visible and is diagnosed, never wiped.
        git clone --no-checkout --filter=blob:none "$url" "$dir" >&2
        git -C "$dir" fetch --depth=1 origin "$revision" >&2
        git -C "$dir" checkout --detach "$revision" >&2
    fi
    [[ -d $dir/.git ]] || die "Unexpected source directory: $dir"
    [[ $(git -C "$dir" remote get-url origin) == "$url" ]] || die "Wrong origin for $dir"
    [[ $(git -C "$dir" rev-parse HEAD) == "$revision" ]] || die "Wrong revision in $dir; preserve it and use a new cache."
    [[ -z $(git -C "$dir" status --porcelain --untracked-files=all) ]] || die "Dirty source checkout: $dir. Preserve your changes; no reset will be performed."
    printf '%s\n' "$dir"
}

download() { # URL SHA256 destination
    local url=$1 digest=$2 destination=$3
    [[ $url == https://* && $digest =~ ^[0-9a-f]{64}$ ]] || die 'Download requires HTTPS and a full SHA256.'
    if [[ -f $destination ]]; then
        printf '%s  %s\n' "$digest" "$destination" | sha256sum -c - >&2 || die "Cached download checksum mismatch: $destination"
        return
    fi
    curl --fail --location --proto '=https' --tlsv1.2 --retry 3 --output "$destination.part" "$url"
    printf '%s  %s\n' "$digest" "$destination.part" | sha256sum -c - >&2 || die "Download checksum mismatch: $url"
    mv -- "$destination.part" "$destination"
}

receipt_valid() {
    python3 "$REPO_DIR/scripts/runtime-metadata.py" receipt-check "$1" "$CACHE/receipts/$1.json"
}
receipt_save() {
    local stage=$1; shift
    python3 "$REPO_DIR/scripts/runtime-metadata.py" receipt-save "$stage" "$CACHE/receipts/$stage.json" "$@"
}

patch_private_elfs() { # root tree, each ELF receives transitive DT_RPATH
    local tree=$1 file old
    while IFS= read -r -d '' file; do
        if is_elf "$file"; then
            old=$(patchelf --print-rpath "$file")
            # Keep module-specific $ORIGIN routes after the pinned toolchain.
            sudo patchelf --force-rpath --set-rpath "$(merge_rpath "$old")" "$file"
        fi
    done < <(find "$tree" -type f -print0)
}

is_elf() { [[ $(od -An -tx1 -N4 "$1") == ' 7f 45 4c 46' ]]; }
merge_rpath() {
    python3 -c 'import sys;print(":".join(dict.fromkeys(p for p in ":".join(sys.argv[1:]).split(":") if p)))' "$PRIVATE_RPATH" "$1"
}

cmake_build() { # component source [extra CMake args]
    local name=$1 src=$2; shift 2
    local build="$CACHE/builds/$name"
    cmake -S "$src" -B "$build" -G Ninja \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_C_COMPILER=gcc-14 -DCMAKE_CXX_COMPILER=g++-14 \
        "-DCMAKE_PREFIX_PATH=$QT_PREFIX;$WAYLAND_PREFIX;/usr/local" \
        "-DCMAKE_INSTALL_RPATH=$QT_PREFIX/lib;$WAYLAND_PREFIX/lib;/usr/local/lib;\$ORIGIN;\$ORIGIN/../lib" \
        -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON "$@"
    cmake --build "$build" --parallel "$JOBS"
    sudo cmake --install "$build"
    # Upstream targets can override INSTALL_RPATH; patch the installed files too.
    while IFS= read -r file; do
        [[ -f $file && ! -L $file ]] || continue
        if is_elf "$file"; then
            local old
            old=$(patchelf --print-rpath "$file")
            sudo patchelf --force-rpath --set-rpath "$(merge_rpath "$old")" "$file"
        fi
    done < "$build/install_manifest.txt"
    sudo ldconfig
}

expose_command() { # name private executable; preserve any existing user command
    local name=$1 target=$2 dest="$HOME/.local/bin/$1"
    mkdir -p "$HOME/.local/bin"
    if [[ -L $dest && $(readlink "$dest") == "$target" ]]; then return; fi
    if [[ -e $dest || -L $dest ]]; then
        local backup
        backup="$dest.before-caelestia-$(date -u +%Y%m%dT%H%M%SZ)-$$"
        cp -a -- "$dest" "$backup"
        log "Saved previous command to $backup"
    fi
    ln -s -- "$target" "$dest.caelestia-new-$$"
    mv -Tf -- "$dest.caelestia-new-$$" "$dest"
}
