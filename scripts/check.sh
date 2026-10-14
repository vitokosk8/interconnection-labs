#!/usr/bin/env bash
# Run the vendor-neutral checks:  scripts/check.sh <vendor>
set -euo pipefail
cd "$(dirname "$0")/.."
VENDOR="${1:?usage: $0 <vendor>}"
ARGS=(--lab "ig-${VENDOR}")
[ "$VENDOR" = "iosxe" ] && ARGS+=(--communities standard)
[ -f "labs/${VENDOR}/known-gaps.txt" ] && ARGS+=(--known-gaps "labs/${VENDOR}/known-gaps.txt")
# cEOS: an x86 image on an ARM host runs under emulation and its
# forwarding agent (Etba) crashes, leaving every Ethernet port down.
if [ "$VENDOR" = eos ] && [ "$(uname -m)" = aarch64 ]; then
  ARCH=$(sudo docker exec clab-ig-eos-dut Cli -p 15 -c "show version" 2>/dev/null | awk '/Architecture/ {print $2}' || true)
  if [ -n "$ARCH" ] && [ "$ARCH" != aarch64 ]; then
    echo "WARNING: cEOS reports architecture '$ARCH' on an ARM host."
    echo "Import the ARM build (cEOSarm-lab-*.tar.xz) instead; see the README."
    echo
  fi
fi
exec sudo python3 common/tests/check.py "${ARGS[@]}"
