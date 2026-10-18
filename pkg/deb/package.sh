#!/usr/bin/env bash
# Turns a configured and built cmake dir into .deb packages. Runs inside the
# container from pkg/deb/Containerfile.
# Usage: DEB_VERSION=<version> package.sh <cmake build dir> <output dir>
set -euo pipefail

build_dir=$1
out_dir=$2
src_dir=$(cd "$(dirname "$0")/../.." && pwd)
arch=$(dpkg --print-architecture)
: "${DEB_VERSION:?DEB_VERSION must be set}"
maintainer="${DEB_MAINTAINER:-fcitx5-osk local build <nobody@localhost>}"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$out_dir"

# dpkg-shlibdeps wants to run next to a debian/control
mkdir -p "$work/debian"
printf 'Source: fcitx5-osk\n\nPackage: fcitx5-osk\nArchitecture: any\n' > "$work/debian/control"

# Install one cmake component into its own tree and turn it into a .deb.
# Usage: make_deb <component> <package> <extra Depends> <description>
make_deb() {
    local component=$1 package=$2 depends=$3 description=$4
    local root="$work/$package"

    DESTDIR="$root" cmake --install "$build_dir" --component "$component"

    local bins shlibs
    mapfile -t bins < <(find "$root/usr/bin" -type f)
    strip --strip-unneeded "${bins[@]}"
    shlibs=$(cd "$work" && dpkg-shlibdeps -O "${bins[@]}" | sed -n 's/^shlibs:Depends=//p')

    mkdir -p "$root/DEBIAN"
    cat > "$root/DEBIAN/control" <<CONTROL
Package: $package
Version: $DEB_VERSION
Architecture: $arch
Maintainer: $maintainer
Installed-Size: $(du -sk --exclude=DEBIAN "$root" | cut -f1)
Depends: ${shlibs:+$shlibs, }$depends
Section: utils
Priority: optional
Homepage: https://github.com/fortime/fcitx5-osk
Description: $description
CONTROL

    if [[ -d "$src_dir/pkg/deb/$package" ]]; then
        install -m 0755 "$src_dir/pkg/deb/$package"/* "$root/DEBIAN/"
    fi

    dpkg-deb --root-owner-group --build "$root" "$out_dir/${package}_${DEB_VERSION}_${arch}.deb"
}

# The GUI dlopens its Wayland/EGL/xkbcommon libraries, so dpkg-shlibdeps misses them
make_deb Fcitx5Osk fcitx5-osk "fcitx5, dbus, libwayland-client0, libwayland-egl1, libegl1, libxkbcommon0" \
    "On-screen keyboard for Fcitx5, especially on KDE Plasma Wayland
 Includes fcitx5-osk-key-helper, a system service that emits modifier key
 events through evdev. Enable it with:
 sudo systemctl enable --now fcitx5-osk-key-helper"

make_deb Fcitx5OskKwinLauncher fcitx5-osk-kwin-launcher "fcitx5-osk (= $DEB_VERSION), kwin-wayland" \
    "KWin virtual keyboard launcher for fcitx5-osk
 Starts fcitx5 and fcitx5-osk as KWin's virtual keyboard. Select
 \"Fcitx 5 Osk Kwin Launcher\" under System Settings > Keyboard >
 Virtual Keyboard."
