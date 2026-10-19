#!/usr/bin/env bash
# Build the .deb packages for Kubuntu 26.04 in a podman container, so no build
# dependencies are needed on the host. The packages are written to dist/.
#   UBUNTU_VERSION  Ubuntu release to build against (default 26.04)
#   DEB_VERSION     package version (default: Cargo.toml version + git commit)
#   NERD_FONTS_VERSION  Nerd Fonts release whose Symbols Nerd Font is bundled
#                       for the key icons (default: pinned in Containerfile;
#                       empty to bundle none)
#   NERD_FONTS_SHA256   sha256 of NerdFontsSymbolsOnly.tar.xz, needed when
#                       NERD_FONTS_VERSION is changed
set -euo pipefail
cd "$(dirname "$0")"

ubuntu_version=${UBUNTU_VERSION:-26.04}
if [[ -z "${DEB_VERSION:-}" ]]; then
    version=$(sed -n 's/^version = "\(.*\)"/\1/p' Cargo.toml | head -n1)
    if git rev-parse --git-dir >/dev/null 2>&1; then
        # Commit date first so newer builds sort as upgrades
        version+="+git$(git log -1 --format=%cd --date=format:%Y%m%d%H%M).$(git rev-parse --short HEAD)"
    fi
    DEB_VERSION="$version-1~ubuntu$ubuntu_version"
fi

font_args=()
if [[ -v NERD_FONTS_VERSION ]]; then
    font_args+=(--build-arg NERD_FONTS_VERSION="$NERD_FONTS_VERSION")
fi
if [[ -v NERD_FONTS_SHA256 ]]; then
    font_args+=(--build-arg NERD_FONTS_SHA256="$NERD_FONTS_SHA256")
fi

rm -rf dist
podman build \
    --file pkg/deb/Containerfile \
    --build-arg UBUNTU_VERSION="$ubuntu_version" \
    --build-arg DEB_VERSION="$DEB_VERSION" \
    "${font_args[@]}" \
    --output type=local,dest=dist \
    .

echo
echo "Built packages:"
ls -1 dist/*.deb
echo
echo "Install with: sudo apt install ./dist/fcitx5-osk_*.deb ./dist/fcitx5-osk-kwin-launcher_*.deb"
