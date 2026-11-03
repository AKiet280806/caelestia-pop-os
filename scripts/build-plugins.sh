#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Build only for the exact pinned distro Hyprland ABI. Never loads plugins.
set -euo pipefail
# shellcheck source=installer/runtime-common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../installer/runtime-common.sh"
[[ $# == 0 ]] || die 'Usage: scripts/build-plugins.sh (no arguments)'
init_runtime
if [[ ${CAELESTIA_RUNTIME_LOCKED:-0} != 1 ]]; then lock_runtime; fi

header=$(pin hyprland.header_file)
version=$(pin hyprland.version)
commit=$(pin hyprland.commit)
[[ -f $header ]] || die "Missing Hyprland development header: $header"
printf '%s  %s\n' "$(pin hyprland.headers_sha256)" "$header" | sha256sum -c - \
    || die 'Hyprland header hash mismatch. Install the pinned package; there is no bypass.'
grep -Eq "^#define GIT_COMMIT_HASH +\"$commit\"$" "$header" || die 'Header commit mismatch.'
[[ $(dpkg-query -W -f='${Version}' hyprland) == "$(pin hyprland.deb_version)" ]] \
    || die 'Installed Hyprland package version differs from pins.json.'
# Do not let private Wayland/Qt pkg-config data change compositor ABI flags.
export PKG_CONFIG_PATH=/usr/share/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig
[[ $(pkg-config --modversion hyprland) == "$version" ]] || die 'Hyprland pkg-config version mismatch.'
command -v g++-14 >/dev/null || die 'Install g++-14 through the dependency stage.'
src=$(fetch_source hyprland_plugins)
dest="${XDG_DATA_HOME:-$HOME/.local/share}/hypr/plugins"
mkdir -p "$dest" "$CACHE/builds/plugins"
[[ ! -L $dest && -O $dest ]] || die 'Plugin destination must be a directory owned by the invoking user.'
if receipt_valid plugins; then log 'Verified plugin products for pinned headers; reusing.'; exit 0; fi

read -r -a core_flags <<< "$(pkg-config --cflags hyprland lua5.4)"
read -r -a bars_flags <<< "$(pkg-config --cflags pixman-1 libdrm libinput libudev wayland-server xkbcommon)"
common=(-shared -fPIC -std=c++23 -fno-gnu-unique -O2)
log 'Build hyprbars for Hyprland 0.57.0'
g++-14 "${common[@]}" "${core_flags[@]}" "${bars_flags[@]}" \
    "$src/hyprbars/main.cpp" "$src/hyprbars/barDeco.cpp" "$src/hyprbars/BarPassElement.cpp" \
    -o "$CACHE/builds/plugins/hyprbars-$version.so"
log 'Build native floating maximize/minimize actions for Hyprland 0.57.0'
g++-14 "${common[@]}" -fvisibility=hidden "${core_flags[@]}" \
    "$REPO_DIR/src/native-window-actions/native-window-actions.cpp" \
    -o "$CACHE/builds/plugins/native-minimize-$version.so"

publish_plugin() {
    local name=$1 temporary
    # A compositor may still map the old inode. Never truncate/overwrite it.
    temporary=$(mktemp "$dest/.$name-$version.so.XXXXXXXX")
    install -m755 "$CACHE/builds/plugins/$name-$version.so" "$temporary"
    nm -D "$temporary" | grep ' pluginInit$' >/dev/null || die "Invalid plugin: $temporary"
    mv -Tf -- "$temporary" "$dest/$name-$version.so"
}
publish_plugin hyprbars
publish_plugin native-minimize
receipt_save plugins "$dest/hyprbars-$version.so" "$dest/native-minimize-$version.so" "$header"
log "Installed plugins atomically in $dest. Load them only in the matching Hyprland session."
