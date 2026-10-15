#!/usr/bin/env bash
# Build a VyOS container image from a VyOS ISO (VyOS ships no container
# image). Needs: docker, bsdtar (libarchive-tools), unsquashfs
# (squashfs-tools), sudo.
#
#   common/images/vyos/build.sh <vyos.iso | https://...iso> [tag]
#
# Free nightly (rolling) ISOs: https://github.com/vyos/vyos-nightly-build/releases
# They are published for amd64 only. The image does NOT work under
# Rosetta on Apple Silicon (vyos-configd never receives the requests
# from vyshim, so every commit stays locked): use an x86_64 host.
set -euo pipefail
SRC="${1:?usage: $0 <vyos.iso|url> [tag]}"
TAG="${2:-vyos:latest}"
case "$SRC" in *arm64*) PLAT=linux/arm64 ;; *) PLAT=linux/amd64 ;; esac
for t in bsdtar unsquashfs docker; do
  command -v $t >/dev/null || { echo "missing $t: sudo apt-get install -y libarchive-tools squashfs-tools"; exit 1; }
done
W=$(mktemp -d)
trap 'sudo rm -rf "$W"' EXIT
if [[ "$SRC" == http* ]]; then
  echo "Downloading $SRC"
  curl -fL -o "$W/vyos.iso" "$SRC"; ISO="$W/vyos.iso"
else
  ISO="$SRC"
fi
echo "Extracting the root filesystem"
bsdtar -xf "$ISO" -C "$W" live/filesystem.squashfs
sudo unsquashfs -q -f -d "$W/rootfs" "$W/live/filesystem.squashfs" >/dev/null
echo "Importing as $TAG ($PLAT)"
# docker import labels the image with the host architecture unless told
sudo tar -C "$W/rootfs" -c . | docker import --platform "$PLAT" \
  --change 'CMD ["/sbin/init"]' - "$TAG"
docker image inspect "$TAG" --format '{{.Architecture}}  {{.Size}}'
