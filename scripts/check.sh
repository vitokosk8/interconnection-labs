#!/usr/bin/env bash
# Run the vendor-neutral checks:  scripts/check.sh <vendor>
set -euo pipefail
cd "$(dirname "$0")/.."
VENDOR="${1:?usage: $0 <vendor>}"
ARGS=(--lab "ig-${VENDOR}")
[ "$VENDOR" = "iosxe" ] && ARGS+=(--communities standard)
[ -f "labs/${VENDOR}/known-gaps.txt" ] && ARGS+=(--known-gaps "labs/${VENDOR}/known-gaps.txt")
exec sudo python3 common/tests/check.py "${ARGS[@]}"
