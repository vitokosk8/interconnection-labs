#!/usr/bin/env python3
"""
Vendor-neutral checks for the Interconnection Guidelines labs.

The DUT is never queried directly. Every result is observed from the FRR
neighbors around it, so the same checks work for every vendor:

  * customer  receives the DUT's full table -> IMPORT tests
              (what the DUT accepted from transit, peer and the IXP)
  * transit, peer, member-a receive what the DUT exports -> EXPORT tests

Usage:
  ./check.py --lab ig-frr                      # all checks
  ./check.py --lab ig-iosxe --communities standard
  ./check.py --lab ig-srlinux --known-gaps ../../labs/srlinux/known-gaps.txt

Exit code: 0 if every check passes (known gaps excluded), 1 otherwise.
Only the Python 3 standard library is used.
"""
import argparse
import json
import subprocess
import sys

# ---------------------------------------------------------------------
# Expected results
#   id, observed at, prefix, expected ("present" / "absent"), lesson, why
# ---------------------------------------------------------------------
CHECKS = [
    # IMPORT - observed at the customer (full table from the DUT)
    ("IMP-VALID",      "customer", "45.10.0.0/16",   "present", "5.2", "RPKI Valid route from transit"),
    ("IMP-NOTFOUND",   "customer", "45.11.0.0/16",   "present", "5.2", "RPKI NotFound route from transit"),
    ("IMP-PEER",       "customer", "45.20.0.0/16",   "present", "4.2", "legitimate route from the private peer"),
    ("IMP-IXP",        "customer", "45.30.0.0/16",   "present", "6.1", "legitimate route via the IXP route servers"),
    ("IMP-RPKI-INVALID", "customer", "45.12.0.0/16", "absent",  "5.2", "RPKI Invalid must be rejected"),
    ("IMP-BOGON",      "customer", "10.0.0.0/8",     "absent",  "3.2", "bogon prefix"),
    ("IMP-TOO-LONG",   "customer", "45.13.1.0/25",   "absent",  "3.2", "prefix longer than /24"),
    ("IMP-OWN-SPACE",  "customer", "203.0.113.0/25", "absent",  "3.4", "more-specific of our own space"),
    ("IMP-IXP-LAN",    "customer", "192.0.2.0/24",   "absent",  "3.4", "IXP peering LAN"),
    ("IMP-BOGON-ASN",  "customer", "45.14.0.0/16",   "absent",  "3.3", "private ASN in the AS path"),
    ("IMP-LONG-PATH",  "customer", "45.15.0.0/16",   "absent",  "3.3", "AS path longer than 50"),
    ("IMP-DEFAULT",    "customer", "0.0.0.0/0",      "absent",  "3.4", "default route from transit"),
    ("IMP-PEER-LEAK",  "customer", "45.21.0.0/16",   "absent",  "3.6", "transit ASN behind a peer"),
    ("IMP-IXP-LEAK",   "customer", "45.31.0.0/16",   "absent",  "3.6", "transit ASN behind an IXP member"),
    # CUSTOMER filtering - observed at transit
    ("CUST-IRR",       "transit",  "198.51.100.0/24", "present", "3.5", "customer prefix in the IRR set is exported upstream"),
    ("CUST-NOT-IRR",   "transit",  "45.40.0.0/16",   "absent",  "3.5", "customer prefix NOT in the IRR set (MANRS NO-1)"),
    # EXPORT - observed at transit, peer and the IXP member
    ("EXP-OWN-TRANSIT", "transit", "203.0.113.0/24", "present", "4.3", "own aggregate announced to transit"),
    ("EXP-OWN-PEER",   "peer",     "203.0.113.0/24", "present", "4.3", "own aggregate announced to the peer"),
    ("EXP-OWN-IXP",    "member-a", "203.0.113.0/24", "present", "4.3", "own aggregate announced via the IXP"),
    ("EXP-CUST-IXP",   "member-a", "198.51.100.0/24", "present", "4.4", "customer route announced via the IXP"),
    ("EXP-DNA-PEER",   "peer",     "198.51.100.0/24", "absent",  "4.6", "customer asked: do not announce to AS64497"),
    ("LEAK-PEER-TO-TRANSIT", "transit", "45.20.0.0/16", "absent", "4.4", "peer route leaked to transit (fake customer tag must be scrubbed)"),
    ("LEAK-IXP-TO-TRANSIT",  "transit", "45.30.0.0/16", "absent", "4.4", "IXP route leaked to transit"),
    ("LEAK-TRANSIT-TO-PEER", "peer",    "45.10.0.0/16", "absent", "4.4", "transit route leaked to the peer"),
    ("LEAK-TRANSIT-TO-IXP",  "member-a", "45.10.0.0/16", "absent", "4.4", "transit route leaked to the IXP"),
    ("LEAK-PEER-TO-IXP",     "member-a", "45.20.0.0/16", "absent", "4.4", "peer route leaked to the IXP"),
]

# Communities expected on routes received by transit (Lesson 4.2)
COMMUNITY_CHECKS = {
    "large": [
        ("COMM-OWN",  "transit", "203.0.113.0/24",  "large", "64500:1:1"),
        ("COMM-CUST", "transit", "198.51.100.0/24", "large", "64500:1:3"),
    ],
    "standard": [
        ("COMM-OWN",  "transit", "203.0.113.0/24",  "standard", "64500:1001"),
        ("COMM-CUST", "transit", "198.51.100.0/24", "standard", "64500:1003"),
    ],
}


def vtysh(container, command):
    out = subprocess.run(
        ["docker", "exec", container, "vtysh", "-c", command],
        capture_output=True, text=True, timeout=30)
    if out.returncode != 0:
        raise RuntimeError(f"{container}: {out.stderr.strip()}")
    return json.loads(out.stdout or "{}")


def table(lab, node):
    data = vtysh(f"clab-{lab}-{node}", "show bgp ipv4 unicast json")
    return {p for p, paths in data.get("routes", {}).items()
            if any(x.get("valid") for x in paths)}


def communities(lab, node, prefix):
    data = vtysh(f"clab-{lab}-{node}", f"show bgp ipv4 unicast {prefix} json")
    std, large = set(), set()
    for path in data.get("paths", []):
        std |= set(path.get("community", {}).get("string", "").split())
        large |= set(path.get("largeCommunity", {}).get("string", "").split())
    return {"standard": std, "large": large}


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--lab", required=True, help="containerlab lab name, e.g. ig-frr")
    ap.add_argument("--communities", choices=["large", "standard", "none"], default="large",
                    help="community scheme used by the DUT (IOS XE edition uses standard)")
    ap.add_argument("--known-gaps", help="file with check IDs expected to fail on this platform")
    args = ap.parse_args()

    gaps = {}
    if args.known_gaps:
        with open(args.known_gaps) as f:
            for line in f:
                line = line.split("#", 1)[0].strip()
                if line:
                    gaps[line.split()[0]] = line

    tables = {}
    for node in sorted({c[1] for c in CHECKS}):
        try:
            tables[node] = table(args.lab, node)
        except Exception as e:  # noqa: BLE001
            print(f"ERROR reading {node}: {e}")
            return 2

    failed = 0
    print(f"{'RESULT':8} {'CHECK':22} {'LESSON':6} {'AT':9} {'PREFIX':18} DESCRIPTION")
    for cid, node, prefix, expect, lesson, why in CHECKS:
        ok = (prefix in tables[node]) == (expect == "present")
        result = "PASS" if ok else ("GAP" if cid in gaps else "FAIL")
        failed += result == "FAIL"
        print(f"{result:8} {cid:22} {lesson:6} {node:9} {prefix:18} {why}")

    if args.communities != "none":
        for cid, node, prefix, kind, value in COMMUNITY_CHECKS[args.communities]:
            seen = communities(args.lab, node, prefix)[kind] if prefix in tables[node] else set()
            ok = value in seen
            result = "PASS" if ok else ("GAP" if cid in gaps else "FAIL")
            failed += result == "FAIL"
            print(f"{result:8} {cid:22} {'4.2':6} {node:9} {prefix:18} carries {kind} community {value}")

    print()
    if gaps:
        print("Known platform gaps (reported as GAP, not counted as failures):")
        for g in gaps.values():
            print(f"  - {g}")
    print("ALL CHECKS PASSED" if not failed else f"{failed} CHECK(S) FAILED")
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
