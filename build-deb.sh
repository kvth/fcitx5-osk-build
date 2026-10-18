#!/usr/bin/env bash
# Build the .deb packages for Kubuntu 26.04 in a podman container, so no build
# dependencies are needed on the host. The packages are written to dist/.
#   UBUNTU_VERSION  Ubuntu release to build against (default 26.04)
#   DEB_VERSION     package version (default: Cargo.toml version + git commit)
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

rm -rf dist
podman build \
    --file pkg/deb/Containerfile \
    --build-arg UBUNTU_VERSION="$ubuntu_version" \
    --build-arg DEB_VERSION="$DEB_VERSION" \
    --output type=local,dest=dist \
    .

echo
echo "Built packages:"
ls -1 dist/*.deb
echo
echo "Install with: sudo apt install ./dist/fcitx5-osk_*.deb ./dist/fcitx5-osk-kwin-launcher_*.deb"
