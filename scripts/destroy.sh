#!/usr/bin/env bash
# Destroy one lab:  scripts/destroy.sh <vendor>   (add --all to also remove br-ixp)
set -euo pipefail
cd "$(dirname "$0")/.."
VENDOR="${1:?usage: $0 <vendor> [--all]}"
sudo containerlab destroy -t "labs/${VENDOR}/${VENDOR}.clab.yml" --cleanup
if [ "${2:-}" = "--all" ]; then
  sudo iptables -D DOCKER-USER -i br-ixp -o br-ixp -j ACCEPT 2>/dev/null || true
  sudo ip link del br-ixp 2>/dev/null || true
fi
