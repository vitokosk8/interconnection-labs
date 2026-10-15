#!/usr/bin/env bash
# Deploy one lab:  scripts/deploy.sh <frr|bird|gobgp|openbgpd|routeros|iosxr|iosxe|sros|srlinux|junos|eos>
set -euo pipefail
cd "$(dirname "$0")/.."
VENDOR="${1:?usage: $0 <vendor>}"
TOPO="labs/${VENDOR}/${VENDOR}.clab.yml"
[ -f "$TOPO" ] || { echo "No lab for '$VENDOR'"; ls labs; exit 1; }
command -v containerlab >/dev/null || { echo "containerlab not found: https://containerlab.dev/install/"; exit 1; }

# 1. Lab images for the route servers, the RTR validators (and the GoBGP / OpenBGPD DUTs)
docker image inspect "${BIRD_IMAGE:-ig/bird:latest}" >/dev/null 2>&1 || docker build -t ig/bird:latest common/images/bird
docker image inspect "${RPKI_IMAGE:-ig/rpki:latest}" >/dev/null 2>&1 || docker build -t ig/rpki:latest common/images/rpki
if [ "$VENDOR" = openbgpd ]; then
  docker image inspect "${OPENBGPD_IMAGE:-ig/openbgpd:latest}" >/dev/null 2>&1 || docker build -t ig/openbgpd:latest common/images/openbgpd
fi
if [ "$VENDOR" = gobgp ]; then
  docker image inspect "${GOBGP_IMAGE:-ig/gobgp:latest}" >/dev/null 2>&1 || docker build -t ig/gobgp:latest common/images/gobgp
fi

# Vendor images that cannot be pulled from a public registry
if [ "$VENDOR" = eos ]; then
  IMG="${CEOS_IMAGE:-ceos:latest}"
  if ! docker image inspect "$IMG" >/dev/null 2>&1; then
    echo "cEOS image '$IMG' not found. Download cEOS-lab from arista.com"
    echo "(cEOSarm-lab-*.tar.xz on Apple Silicon, cEOS64-lab-*.tar.xz on x86_64), then:"
    echo "  docker import /path/to/cEOS*-lab-*.tar.xz $IMG"
    exit 1
  fi
fi

if [ "$VENDOR" = junos ]; then
  IMG="${CRPD_IMAGE:-crpd:latest}"
  if ! docker image inspect "$IMG" >/dev/null 2>&1; then
    echo "cRPD image '$IMG' not found. Download cRPD from juniper.net (arm64 build on"
    echo "Apple Silicon), then:  docker load -i junos-routing-crpd-*.tgz"
    echo "and tag it:            docker tag crpd:<version> $IMG"
    exit 1
  fi
fi
if [ "$VENDOR" = routeros ]; then
  IMG="${ROS_IMAGE:-vrnetlab/mikrotik_routeros:latest}"
  if ! docker image inspect "$IMG" >/dev/null 2>&1; then
    echo "RouterOS image '$IMG' not found. Build it with vrnetlab (see the README):"
    echo "  CHR image from mikrotik.com/download (chr-7.x-arm64.vdi on Apple Silicon,"
    echo "  chr-7.x.vmdk on x86_64) -> srl-labs/vrnetlab mikrotik/routeros -> make"
    echo "then: docker tag vrnetlab/mikrotik_routeros:<version> $IMG"
    exit 1
  fi
fi

# 2. The IXP peering LAN is a Linux bridge on the host
if ! ip link show br-ixp >/dev/null 2>&1; then
  sudo ip link add name br-ixp type bridge
  sudo ip link set br-ixp up
fi
# Docker sets FORWARD to DROP and bridged frames hit iptables when
# br_netfilter is loaded: let the IXP LAN forward between its ports.
if command -v iptables >/dev/null && sudo iptables -L DOCKER-USER >/dev/null 2>&1; then
  sudo iptables -C DOCKER-USER -i br-ixp -o br-ixp -j ACCEPT 2>/dev/null \
    || sudo iptables -I DOCKER-USER -i br-ixp -o br-ixp -j ACCEPT
fi

# 3. Deploy
# sudo drops the environment on many systems (sudo -E is often refused),
# so pass the image overrides to containerlab explicitly.
ENV_PASS=()
for v in FRR_IMAGE BIRD_IMAGE RPKI_IMAGE GOBGP_IMAGE OPENBGPD_IMAGE CRPD_IMAGE SRL_IMAGE CEOS_IMAGE ROS_IMAGE XRD_IMAGE \
         C8KV_IMAGE SROS_IMAGE SROS_LICENSE VJUNOS_IMAGE; do
  [ -n "${!v:-}" ] && ENV_PASS+=("$v=${!v}")
done
sudo env "${ENV_PASS[@]}" containerlab deploy -t "$TOPO" --reconfigure
echo
echo "Wait until the DUT has booted and its BGP sessions are up (VM-based"
echo "images can take several minutes), then run:  scripts/check.sh $VENDOR"
