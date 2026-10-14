#!/usr/bin/env bash
# Deploy one lab:  scripts/deploy.sh <frr|bird|routeros|iosxr|iosxe|sros|srlinux|junos|eos>
set -euo pipefail
cd "$(dirname "$0")/.."
VENDOR="${1:?usage: $0 <vendor>}"
TOPO="labs/${VENDOR}/${VENDOR}.clab.yml"
[ -f "$TOPO" ] || { echo "No lab for '$VENDOR'"; ls labs; exit 1; }
command -v containerlab >/dev/null || { echo "containerlab not found: https://containerlab.dev/install/"; exit 1; }

# 1. Lab images for the route servers and the RTR validators
docker image inspect "${BIRD_IMAGE:-ig/bird:latest}" >/dev/null 2>&1 || docker build -t ig/bird:latest common/images/bird
docker image inspect "${RPKI_IMAGE:-ig/rpki:latest}" >/dev/null 2>&1 || docker build -t ig/rpki:latest common/images/rpki

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
sudo -E containerlab deploy -t "$TOPO" --reconfigure
echo
echo "Wait until the DUT has booted and its BGP sessions are up (VM-based"
echo "images can take several minutes), then run:  scripts/check.sh $VENDOR"
