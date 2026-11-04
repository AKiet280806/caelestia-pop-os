#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Explicit, resumable build stages. This never deploys desktop configuration,
# changes the display manager, installs apt packages or starts a desktop service.
set -euo pipefail
# shellcheck source=installer/runtime-common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/runtime-common.sh"

usage() {
    printf '%s\n' 'Usage: installer/runtime.sh STAGE' \
        'Stages: toolchain wayland cava quickshell m3shapes shell cli fonts tools plugins hyprmod aiusage all' \
        'all excludes optional hyprmod/aiusage. First install apt dependencies with the Python installer.' \
        'CAELESTIA_CACHE_DIR selects a private cache; CAELESTIA_JOBS defaults to 2.'
}

require_toolchain() {
    [[ -x $QT_PREFIX/bin/qmake6 ]] || die 'Run the toolchain stage first.'
    [[ $("$QT_PREFIX/bin/qmake6" -query QT_VERSION) == "$(pin qt.version)" ]] || die 'Qt version mismatch.'
    [[ -f $WAYLAND_PREFIX/include/wayland-client-protocol.h ]] || die 'Run the wayland stage first.'
    grep -q wl_fixes "$WAYLAND_PREFIX/include/wayland-client-protocol.h" || die 'Private Wayland headers lack wl_fixes.'
}

uv_binary() { printf '%s\n' "$PIPX_BIN_DIR/uv"; }
require_uv() {
    [[ -x $(uv_binary) ]] || die 'Run the toolchain stage first (private uv is missing).'
    [[ $($(uv_binary) --version) == "uv $(pin python.uv_version)"* ]] || die 'Private uv version mismatch.'
}

save_cmake_receipt() {
    local stage=$1
    local -a products
    mapfile -t products < "$CACHE/builds/$stage/install_manifest.txt"
    receipt_save "$stage" "${products[@]}"
}

stage_toolchain() {
    log 'Pinned private uv, managed Python and Qt'
    command -v pipx >/dev/null || die 'Missing distro pipx; run the apt dependency stage first.'
    if [[ ! -x $(uv_binary) ]]; then
        pipx install --python /usr/bin/python3 "uv==$(pin python.uv_version)"
    fi
    require_uv
    local uv aqt qt_root qt_version qt_download
    uv=$(uv_binary); qt_version=$(pin qt.version); qt_root="${QT_PREFIX%/"$qt_version"/gcc_64}"
    "$uv" python install "$(pin python.version)"
    # --python-version is never applied to distro /usr/bin/python3.
    "$uv" tool install --python "$(pin python.version)" "aqtinstall==$(pin python.aqtinstall_version)"
    aqt="$DATA/bin/aqt"
    if [[ -e $QT_PREFIX ]]; then
        [[ -x $QT_PREFIX/bin/qmake6 ]] || die "Incomplete existing Qt at $QT_PREFIX; preserve/move it manually before retrying."
        [[ $("$QT_PREFIX/bin/qmake6" -query QT_VERSION) == "$qt_version" ]] || die 'Existing Qt version differs from pins.'
        [[ -f $QT_PREFIX/plugins/imageformats/libqwebp.so && -x $QT_PREFIX/bin/qsb ]] || die 'Qt imageformats or shadertools missing; complete that installation manually.'
    else
        qt_download="$CACHE/builds/qt"
        mkdir -p "$qt_download"
        local -a modules
        mapfile -t modules < <(pin qt.modules)
        "$aqt" install-qt linux desktop "$qt_version" linux_gcc_64 -O "$qt_download" -m "${modules[@]}"
        [[ -f $qt_download/$qt_version/gcc_64/plugins/imageformats/libqwebp.so ]] || die 'Qt download lacks WebP support.'
        sudo install -d "$qt_root"
        sudo cp -a "$qt_download/$qt_version" "$qt_root/"
    fi
    # DT_RPATH applies transitively to QtWayland plugins; no session-wide
    # LD_LIBRARY_PATH is needed or permitted by the shipped launch wrappers.
    if ! receipt_valid toolchain; then
        patch_private_elfs "$QT_PREFIX"
        receipt_save toolchain "$QT_PREFIX" "$(uv_binary)"
    fi
    env -u LD_LIBRARY_PATH "$QT_PREFIX/bin/qmake6" -query QT_VERSION
    "$uv" python find "$(pin python.version)"
}

stage_wayland() {
    log 'Wayland 1.26 in its own /opt prefix; distro Wayland remains installed'
    local src build
    src=$(fetch_source wayland wayland)
    if receipt_valid wayland; then log 'Verified installed Wayland; reusing.'; return; fi
    build="$CACHE/builds/wayland"
    if [[ ! -f $build/build.ninja ]]; then
        meson setup "$build" "$src" --prefix="$WAYLAND_PREFIX" --libdir=lib \
            -Ddocumentation=false -Ddtd_validation=false -Dtests=false
    fi
    meson compile -C "$build" -j "$JOBS"
    sudo meson install -C "$build"
    # No /etc/ld.so.conf entry: only Caelestia ELFs reference these libraries.
    patch_private_elfs "$WAYLAND_PREFIX"
    [[ $(PKG_CONFIG_PATH="$WAYLAND_PREFIX/lib/pkgconfig" pkg-config --modversion wayland-client) == "$(pin wayland.version)" ]] || die 'Private Wayland version mismatch.'
    grep -q wl_fixes "$WAYLAND_PREFIX/include/wayland-client-protocol.h" || die 'wl_fixes is missing.'
    receipt_save wayland "$WAYLAND_PREFIX"
}

stage_cava() {
    log 'Pinned libcava and terminal visualizer'
    local src build revision
    src=$(fetch_source cava)
    if receipt_valid cava; then log 'Verified installed libcava; reusing.'; return; fi
    revision=$(pin sources.cava.commit)
    build="$CACHE/builds/cava-$revision"
    # Autotools writes into its source directory. Export a build copy so the
    # audited git checkout always stays clean and user edits are never reset.
    if [[ ! -d $build ]]; then
        mkdir -p "$build"
        git -C "$src" archive HEAD | tar -x -C "$build"
    fi
    (
        cd "$build"
        [[ -x configure ]] || ./autogen.sh
        if [[ ! -f Makefile ]]; then ./configure --prefix=/usr/local --libdir=/usr/local/lib; fi
        make -j"$JOBS"
        sudo make install
    )
    sudo ldconfig
    pkg-config --exists libcava || die 'libcava pkg-config metadata missing.'
    [[ -x /usr/local/bin/cava ]] || die 'Terminal cava executable missing.'
    # A distinct name is useful for terminals while preserving upstream cava.
    sudo ln -sfn cava /usr/local/bin/terminalcava
    receipt_save cava /usr/local/bin/cava /usr/local/bin/terminalcava \
        /usr/local/lib/libcava.so /usr/local/lib/pkgconfig/libcava.pc /usr/local/include/cava
}

stage_quickshell() {
    log 'Pinned Quickshell with pinned cpptrace and private Qt/Wayland'
    require_toolchain
    local src trace
    src=$(fetch_source quickshell); trace=$(fetch_source cpptrace)
    if receipt_valid quickshell; then
        env -u LD_LIBRARY_PATH /usr/local/bin/qs --version
        log 'Verified installed Quickshell; reusing.'; return
    fi
    cmake_build quickshell "$src" -DVENDOR_CPPTRACE=ON \
        "-DFETCHCONTENT_SOURCE_DIR_CPPTRACE=$trace" -DFETCHCONTENT_UPDATES_DISCONNECTED=ON \
        -DINSTALL_QMLDIR=/usr/local/lib/qt6/qml
    [[ -d /usr/local/lib/qt6/qml/Quickshell ]] || die 'Quickshell QML module not installed.'
    env -u LD_LIBRARY_PATH /usr/local/bin/qs --version
    save_cmake_receipt quickshell
}

stage_m3shapes() {
    log 'Pinned M3Shapes in /usr/local/lib/qt6/qml'
    require_toolchain
    local src
    src=$(fetch_source m3shapes)
    if receipt_valid m3shapes; then log 'Verified installed M3Shapes; reusing.'; return; fi
    cmake_build m3shapes "$src" -DINSTALL_QMLDIR=lib/qt6/qml
    [[ -f /usr/local/lib/qt6/qml/M3Shapes/qmldir ]] || die 'M3Shapes QML module missing.'
    save_cmake_receipt m3shapes
}

stage_shell() {
    log 'Build the shipped, modified Caelestia source (extras + plugin only)'
    require_toolchain
    pkg-config --exists libcava || die 'Run the cava stage first.'
    [[ -f /usr/local/lib/qt6/qml/M3Shapes/qmldir ]] || die 'Run the m3shapes stage first.'
    if receipt_valid shell; then log 'Verified installed Caelestia helpers/modules; reusing.'; return; fi
    # User configuration deployment belongs exclusively to the Python installer.
    # The export has no .git; explicitly supply upstream version provenance.
    cmake_build shell "$REPO_DIR/shell" \
        "-DVERSION=$(pin shell.version)" "-DGIT_REVISION=$(pin shell.upstream_commit)" \
        -DDISTRIBUTOR=caelestia-pop-os '-DENABLE_MODULES=extras;plugin' \
        -DINSTALL_QMLDIR=lib/qt6/qml -DINSTALL_LIBDIR=lib/caelestia
    [[ -x /usr/local/lib/caelestia/version ]] || die 'Caelestia version helper missing.'
    [[ -f /usr/local/lib/qt6/qml/Caelestia/qmldir ]] || die 'Caelestia QML module missing.'
    /usr/local/lib/caelestia/version -s
    save_cmake_receipt shell
}

stage_cli() {
    log 'Pinned Caelestia CLI in a managed Python 3.13 tool environment'
    require_uv
    local src constraints uv venv
    src=$(fetch_source cli); uv=$(uv_binary)
    constraints="$CACHE/builds/cli-constraints.txt"
    python3 "$REPO_DIR/scripts/runtime-metadata.py" constraints cli > "$constraints"
    venv="$UV_TOOL_DIR/caelestia"
    if ! receipt_valid cli; then
        # Install the audited commit, never the remote's moving default branch.
        "$uv" tool install --force --python "$(pin python.version)" \
            --constraint "$constraints" "git+$(pin sources.cli.url)@$(pin sources.cli.commit)"
        "$venv/bin/python" "$REPO_DIR/scripts/patch-cli.py" --venv "$venv"
        receipt_save cli "$venv" "$DATA/bin/caelestia"
    fi
    expose_command caelestia "$DATA/bin/caelestia"
    "$venv/bin/python" "$REPO_DIR/scripts/patch-cli.py" --venv "$venv" --check
    "$DATA/bin/caelestia" --help >/dev/null
    # fetch_source is deliberate: it leaves browsable, clean, pinned sources.
    [[ -d $src/.git ]] || die 'CLI source checkout missing.'
}

stage_fonts() {
    log 'Checksum-pinned fonts and their upstream licenses'
    local count i file fontdir licensedir archive
    fontdir="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/caelestia-pop-os"
    licensedir="$DATA/licenses/fonts"
    mkdir -p "$fontdir" "$licensedir"
    if receipt_valid fonts; then log 'Verified installed fonts; reusing.'; return; fi
    count=$(python3 -c 'import json,sys;print(len(json.load(open(sys.argv[1]))["fonts"]))' "$PIN_FILE")
    for ((i=0; i<count; i++)); do
        file=$(pin "fonts.$i.filename"); archive="$CACHE/downloads/$file"
        download "$(pin "fonts.$i.url")" "$(pin "fonts.$i.sha256")" "$archive"
        download "$(pin "fonts.$i.license_url")" "$(pin "fonts.$i.license_sha256")" "$CACHE/downloads/$file.LICENSE"
        install -m644 "$CACHE/downloads/$file.LICENSE" "$licensedir/$file.LICENSE"
        if [[ $file == *.zip ]]; then
            # -j discards archive directory names; only fonts are extracted.
            unzip -jo "$archive" '*.ttf' -d "$fontdir"
        else
            install -m644 "$archive" "$fontdir/$file"
        fi
    done
    fc-cache -f "$fontdir"
    receipt_save fonts "$fontdir" "$licensedir"
}

stage_tools() {
    log 'Standalone pinned Sass and pinned Swappy'
    local sass_dir sass_archive src build
    src=$(fetch_source swappy)
    if receipt_valid tools; then log 'Verified installed Sass/Swappy; reusing.'; return; fi
    sass_dir="$DATA/sass-$(pin sass.version)"
    sass_archive="$CACHE/downloads/dart-sass-$(pin sass.version)-linux-x64.tar.gz"
    download "$(pin sass.url)" "$(pin sass.sha256)" "$sass_archive"
    mkdir -p "$sass_dir"
    tar --extract --gzip --file "$sass_archive" --directory "$sass_dir" --no-same-owner
    printf '#!/usr/bin/env bash\nexec %q "$@"\n' "$sass_dir/dart-sass/sass" > "$DATA/bin/sass"
    chmod 755 "$DATA/bin/sass"
    expose_command sass "$DATA/bin/sass"
    "$DATA/bin/sass" --version
    build="$CACHE/builds/swappy"
    if [[ ! -f $build/build.ninja ]]; then
        meson setup "$build" "$src" --prefix=/usr/local --buildtype=release -Dman-pages=disabled
    fi
    meson compile -C "$build" -j "$JOBS"
    sudo meson install -C "$build"
    [[ -x /usr/local/bin/swappy ]] || die 'Swappy executable missing.'
    /usr/local/bin/swappy --version
    receipt_save tools "$sass_dir" "$DATA/bin/sass" /usr/local/bin/swappy
}

stage_plugins() {
    # Inherit lock descriptor rather than trying to acquire our own lock twice.
    CAELESTIA_RUNTIME_LOCKED=1 "$REPO_DIR/scripts/build-plugins.sh"
}

stage_hyprmod() {
    log 'Optional pinned Hyprmod using distro Python 3.12 and isolated Python packages'
    require_uv
    [[ -x /usr/bin/python3.12 ]] || die 'Hyprmod needs distro Python 3.12 plus GTK4/libadwaita build dependencies.'
    local src constraints venv uv
    src=$(fetch_source hyprmod); uv=$(uv_binary)
    constraints="$CACHE/builds/hyprmod-constraints.txt"
    python3 "$REPO_DIR/scripts/runtime-metadata.py" constraints hyprmod > "$constraints"
    venv="$UV_TOOL_DIR/hyprmod"
    if ! receipt_valid hyprmod; then
        "$uv" tool install --force --python /usr/bin/python3.12 --constraint "$constraints" \
            "git+$(pin sources.hyprmod.url)@$(pin sources.hyprmod.commit)"
        "$venv/bin/python" -c 'import gi; gi.require_version("Gtk", "4.0"); gi.require_version("Adw", "1"); from gi.repository import Gtk, Adw'
        "$DATA/bin/hyprmod" --install
        receipt_save hyprmod "$venv" "$DATA/bin/hyprmod"
    fi
    expose_command hyprmod "$DATA/bin/hyprmod"
    [[ -d $src/.git ]] || die 'Hyprmod source checkout missing.'
}

stage_aiusage() {
    log 'Pinned multi-provider usage CLI (no Swift toolchain or extra desktop)'
    local version archive prefix staging
    version=$(pin codexbar.version)
    archive="$CACHE/downloads/CodexBarCLI-v$version-linux-x86_64.tar.gz"
    prefix="$DATA/codexbar-$version"
    if ! receipt_valid aiusage; then
        [[ ! -e $prefix ]] || die "Existing unverified usage runtime at $prefix; preserve it before retrying."
        download "$(pin codexbar.url)" "$(pin codexbar.sha256)" "$archive"
        staging=$(mktemp -d "$DATA/.codexbar-$version.XXXXXXXX")
        # Python's data filter rejects archive paths and links outside staging.
        python3 - "$archive" "$staging" <<'PY'
import sys, tarfile
with tarfile.open(sys.argv[1]) as archive:
    archive.extractall(sys.argv[2], filter='data')
PY
        [[ -x $staging/CodexBarCLI && -d $staging/CodexBar_CodexBarCore.bundle ]] \
            || die 'Incomplete usage CLI archive; executable and resource bundle are required.'
        "$staging/CodexBarCLI" --version
        mv -T -- "$staging" "$prefix"
        receipt_save aiusage "$prefix"
    fi
    expose_command codexbar "$prefix/CodexBarCLI"
    "$prefix/CodexBarCLI" --version
}

main() {
    [[ $# == 1 ]] || { usage >&2; exit 2; }
    case "$1" in
        -h|--help|help) usage; return ;;
        toolchain|wayland|cava|quickshell|m3shapes|shell|cli|fonts|tools|plugins|hyprmod|aiusage|all) ;;
        *) usage >&2; die "Unknown stage: $1" ;;
    esac
    init_runtime
    lock_runtime
    # Preserve full diagnostics in the caller-selected private build cache.
    exec > >(tee -a "$CACHE/logs/$1.log") 2>&1
    if [[ $1 == all ]]; then
        local stage
        for stage in toolchain wayland cava quickshell m3shapes shell cli fonts tools plugins; do
            "stage_$stage"
        done
    else
        "stage_$1"
    fi
}
main "$@"
