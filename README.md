# Interconnection Labs

**Hands-on BGP labs for the course _Interconnection Guidelines and Operational Best Practices_.**

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![containerlab](https://img.shields.io/badge/containerlab-0.74%2B-0aa8a7.svg)](https://containerlab.dev)
[![MANRS](https://img.shields.io/badge/aligned%20with-MANRS-1f4e79.svg)](https://manrs.org)

Reading about route leaks is one thing. Watching your own router let one through is another.

Each lab drops a single router under test (the **DUT**, AS64500) into a small, realistic Internet: a transit provider, a private peer, an Internet Exchange with two route servers, a customer and two RPKI validators. The neighbours announce good routes **and traps**: bogons, RPKI Invalids, leaks, more-specifics of your own space, forged communities. A vendor-neutral script then looks at what your router accepted and what it announced, and tells you, check by check, whether your policy holds.

The same policy and the same 28 checks run on many platforms, so you can compare how FRR, BIRD, Arista, Nokia, MikroTik and others express the same MANRS-aligned best practices, and where each one surprises you.

## Contents

- [Platforms](#platforms)
- [The lab at a glance](#the-lab-at-a-glance)
- [Getting started](#getting-started)
- [Vendor images](#vendor-images)
- [What the checks test](#what-the-checks-test)
- [The ASPA lab](#the-aspa-lab)
- [MANRS mapping](#manrs-mapping)
- [Exercises](#exercises)
- [Repository layout](#repository-layout)
- [Troubleshooting and lessons learned](#troubleshooting-and-lessons-learned)
- [References](#references)
- [License](#license)

## Platforms

✅ validated on containerlab  ·  🧪 ready, waiting for an image  ·  💻 x86_64 hosts only  ·  🗓️ planned

| | Lab | Router under test | Image | Result |
| :-: | --- | --- | --- | --- |
| ✅ | `frr` | FRRouting 10.2.1 | public (`quay.io/frrouting/frr`) | 28/28 |
| ✅ | `bird` | BIRD 2.17.5 | built by `deploy.sh` | 28/28 |
| ✅ | `bird3` | BIRD 3.4.0 (multi-threaded) | built from source by `deploy.sh bird3` | 28/28 |
| ✅ | `gobgp` | GoBGP 4.10.0 | built by `deploy.sh` | 28/28 |
| ✅ | `openbgpd` | OpenBGPD 8.8 (portable, same `bgpd.conf` as OpenBSD) | built by `deploy.sh` | 28/28 |
| ✅ | `srlinux` | Nokia SR Linux 26.7.2 | public (`ghcr.io/nokia/srlinux`) | 27/28 + 1 gap (no ROV) |
| ✅ | `eos` | Arista cEOS-lab 4.36.2F | free download, [see below](#arista-ceos) | 28/28 |
| ✅ | `routeros` | MikroTik RouterOS 7.23.8 (CHR) | free download, [see below](#mikrotik-routeros-chr) | 28/28 |
| 🧪 | `junos` | Juniper cRPD (the Junos routing engine) | juniper.net account, [see below](#juniper-crpd) | not run yet |
| 💻 | `vyos` | VyOS rolling | built from the ISO, [see below](#vyos) | 28/28 on x86_64, outside containerlab |
| 🗓️ | `iosxe` | Cisco IOS XE (IOL, from CML Free) | Cisco.com account | planned |
| 🗓️ | `iosxr` | Cisco IOS XR (XRd) | Cisco.com account | planned |
| 🗓️ | `sros` | Nokia SR OS (MD-CLI) | vSIM + licence | planned |

Two smaller labs focus on **ASPA**, path validation against route leaks, on the platforms that implement it:

| | Lab | Router under test | Result |
| :-: | --- | --- | --- |
| ✅ | `aspa-bird` | BIRD 2.17.5 | 8/8 |
| ✅ | `aspa-bird3` | BIRD 3.4.0 | 8/8 |
| ✅ | `aspa-openbgpd` | OpenBGPD 8.8 | 8/8 |

Every result above comes from a real run on containerlab 0.74.3 (on an Apple Silicon Mac with OrbStack), except VyOS. A lab is only marked ✅ once it passes there.

## The lab at a glance

```mermaid
flowchart TB
  transit["transit<br/>AS64496 · FRR"] ---|"eth1 · 198.51.100.0/30"| dut
  peer["peer<br/>AS64497 · FRR"] ---|"eth2 · 198.51.100.8/30"| dut
  dut(["DUT<br/>AS64500"]) ---|"eth4 · 198.51.100.16/30"| customer["customer<br/>AS64511 · FRR"]
  dut ---|"eth3 · .50"| ixp{{"IXP LAN 192.0.2.0/24 (br-ixp)"}}
  ixp --- rs1["rs1 .1<br/>AS64510 · BIRD"]
  ixp --- rs2["rs2 .2<br/>AS64510 · BIRD"]
  ixp --- member["member-a .99<br/>AS64499 · FRR"]
  ixp --- rpki1["rpki1 .53<br/>StayRTR"]
  ixp --- rpki2["rpki2 .54<br/>StayRTR"]
```

- **transit** sells you the Internet: a default route, some real-looking routes and most of the traps.
- **peer** exchanges its own routes with you, and slips in one it should not.
- **The IXP** has two transparent route servers and another member (**member-a**) that also misbehaves.
- **customer** buys transit from you. It receives your full table, which makes it the place where the checks see everything you accepted.
- **rpki1 / rpki2** serve the ROAs over RTR. They sit on the IXP LAN only to keep the lab small; in production they belong in your own network.

## Getting started

**You need** a Linux host with Docker, [containerlab](https://containerlab.dev/install/), Python 3 and `sudo`.

**On a Mac**, run everything inside a Linux VM. [OrbStack](https://orbstack.dev) works well and shares `/Users` with the VM, so you edit on the Mac and run the lab in the VM:

```bash
orb create ubuntu clab && orb -m clab
curl -sL https://containerlab.dev/setup | sudo -E bash -s "all"   # Docker + containerlab
sudo usermod -aG docker $USER && exit                            # then: orb -m clab
```

On Apple Silicon, every ✅ lab runs natively. MikroTik is the pleasant surprise: it publishes an arm64 CHR. VyOS, IOS XR, SR OS and full Junos (vJunos) need an x86_64 host.

**Your first lab:**

```bash
git clone https://github.com/vitokosk8/interconnection-labs.git
cd interconnection-labs
scripts/deploy.sh frr        # builds the BIRD and RTR images the first time
sleep 90
scripts/check.sh frr         # 28 checks: PASS / FAIL / GAP
scripts/destroy.sh frr       # add --all to also remove the br-ixp bridge
```

A few things worth knowing:

- **Run one lab at a time.** They all share the host bridge `br-ixp`.
- **Give it about 90 seconds** before the checks. BGP is up in seconds, but the RPKI validators may take longer. Until they connect, the router cannot know that 45.12.0.0/16 is Invalid, and `IMP-RPKI-INVALID` fails. That is ROV failing open (Lesson 5.2), not a broken filter. VM-based routers (RouterOS) and slow boots (cEOS) need a little more.
- **Images can be overridden** with environment variables, e.g. `FRR_IMAGE=quay.io/frrouting/frr:10.3.1 scripts/deploy.sh frr`.

| Variable | Default |
| --- | --- |
| `FRR_IMAGE` | `quay.io/frrouting/frr:10.2.1` |
| `BIRD_IMAGE` / `RPKI_IMAGE` | `ig/bird:latest` / `ig/rpki:latest`, built by `deploy.sh` |
| `BIRD3_IMAGE` | `ig/bird3:latest`, built from source by `deploy.sh bird3` (BIRD 3.4.0) |
| `GOBGP_IMAGE` | `ig/gobgp:latest`, built by `deploy.sh gobgp` |
| `OPENBGPD_IMAGE` | `ig/openbgpd:latest`, built by `deploy.sh openbgpd` |
| `SRL_IMAGE` | `ghcr.io/nokia/srlinux:26.7.2` |
| `CEOS_IMAGE` | `ceos:latest`, you import it |
| `ROS_IMAGE` | `vrnetlab/mikrotik_routeros:latest`, you build it |
| `CRPD_IMAGE` | `crpd:latest`, you load it |
| `VYOS_IMAGE` | `vyos:latest`, you build it |

## Vendor images

FRR and SR Linux pull from public registries, and BIRD, GoBGP and OpenBGPD are built for you. The commercial platforms need an image you download yourself; `deploy.sh` checks for it and tells you what is missing.

### Arista cEOS

<details>
<summary>Free with an arista.com account. Take the <b>ARM</b> build on Apple Silicon.</summary>

Software Downloads → EOS → cEOS-lab. On Apple Silicon download `cEOSarm-lab-<version>.tar.xz`; on x86_64, `cEOS64-lab-<version>.tar.xz`. Then, in the Linux VM:

```bash
docker import cEOSarm-lab-*.tar.xz ceos:latest
scripts/deploy.sh eos
sleep 150 && scripts/check.sh eos      # cEOS needs 1-2 minutes to boot
```

Make sure you got the right build: `docker exec clab-ig-eos-dut Cli -c "show version" | grep Architecture` must say `aarch64` on Apple Silicon. An x86 image still starts under emulation, but its forwarding agent crashes and every Ethernet port stays down ("BGP inactive"). `docker image inspect` will not warn you, because `docker import` labels the image with your machine's architecture whatever is inside. `scripts/check.sh eos` does warn you.
</details>

### MikroTik RouterOS (CHR)

<details>
<summary>Free download. Runs as a VM inside a container built with vrnetlab, arm64 or x86_64.</summary>

Download the CHR disk image from [mikrotik.com/download](https://mikrotik.com/download), stable 7.20 or later: the **arm64 VDI** on Apple Silicon, the **VMDK** on x86_64. Then, in the Linux VM:

```bash
sudo apt-get install -y make
git clone https://github.com/srl-labs/vrnetlab.git && cd vrnetlab
./build-base-image.sh 0.3.0        # Apple Silicon only: the published base image is amd64-only
cp /path/to/chr-7.*-arm64.vdi mikrotik/routeros/
cd mikrotik/routeros && make
docker images | grep mikrotik_routeros                 # e.g. 7.23.8-arm64
docker tag vrnetlab/mikrotik_routeros:7.23.8-arm64 vrnetlab/mikrotik_routeros:latest
```

Use the base-image tag that `mikrotik/routeros/docker/Dockerfile` expects. Without the native base image, the build warns `InvalidBaseImagePlatform ... linux/amd64` and the result has the wrong QEMU. `/dev/kvm` is not required: on an M1/M2 Mac without it, CHR still boots in about 25 seconds. Containerlab maps `eth1`-`eth4` to `ether2`-`ether5`; `ether1` is management.
</details>

### Juniper cRPD

<details>
<summary>Juniper account required (free trial available). The Junos routing engine, without the dataplane.</summary>

cRPD runs Junos's `rpd` and CLI in a container, arm64 and amd64, with the same `policy-options` and `protocols bgp` configuration as an MX or vJunos. Interfaces, firewall filters and uRPF are not part of it; those sections are in the reference configuration.

```bash
docker load -i junos-routing-crpd-docker-*.tgz
docker images | grep crpd                              # e.g. crpd:25.2R1.9
docker tag crpd:25.2R1.9 crpd:latest
scripts/deploy.sh junos
```

`startup.sh` loads `labs/junos/dut/config.set` once the management daemon is up, about a minute after deploy, and writes the result to `/tmp/lab-load.log` inside the container. If you have a licence file, uncomment `license:` in `junos.clab.yml`.
</details>

### VyOS

<details>
<summary>Free nightly ISOs. x86_64 only: does not run under Rosetta.</summary>

VyOS publishes no container image, so `common/images/vyos/build.sh` builds one from an ISO. The nightly (rolling) ISOs are on [github.com/vyos/vyos-nightly-build](https://github.com/vyos/vyos-nightly-build/releases), amd64 only.

```bash
sudo apt-get install -y libarchive-tools squashfs-tools
common/images/vyos/build.sh https://github.com/vyos/vyos-nightly-build/releases/download/2026.10.07-0712-rolling/vyos-2026.10.07-0712-rolling-generic-amd64.iso
scripts/deploy.sh vyos
```

VyOS boots with systemd; `labs/vyos/dut/startup.sh` then applies `config.vyos`, commits and saves (about two minutes, log in `/tmp/lab-load.log`). VyOS renders the configuration into FRR, so `vtysh` works inside the container too.

On Apple Silicon the amd64 image boots under Rosetta, but its configuration daemon (`vyos-configd`) never receives the requests from `vyshim`, so the boot configuration hangs and every commit fails with "Configuration system temporarily locked".
</details>

## What the checks test

The router under test is never queried directly: every result is observed from its neighbours, so the same checks work on any vendor. The **customer** receives the full table and shows what the DUT accepted; **transit, peer and member-a** show what it announced.

**Inbound filtering** (seen at the customer)

| Check | Route | Expected | Lesson |
| --- | --- | :-: | :-: |
| IMP-VALID | 45.10.0.0/16, RPKI Valid | ✔ accepted | 5.2 |
| IMP-NOTFOUND | 45.11.0.0/16, RPKI NotFound | ✔ accepted | 5.2 |
| IMP-PEER | 45.20.0.0/16 from the peer | ✔ accepted | 4.2 |
| IMP-IXP | 45.30.0.0/16 via the route servers | ✔ accepted | 6.1 |
| IMP-RPKI-INVALID | 45.12.0.0/16, RPKI Invalid | ✘ rejected | 5.2 |
| IMP-BOGON | 10.0.0.0/8 | ✘ rejected | 3.2 |
| IMP-TOO-LONG | 45.13.1.0/25 | ✘ rejected | 3.2 |
| IMP-OWN-SPACE | 203.0.113.0/25, a more-specific of your space | ✘ rejected | 3.4 |
| IMP-IXP-LAN | 192.0.2.0/24, the peering LAN | ✘ rejected | 3.4 |
| IMP-BOGON-ASN | 45.14.0.0/16 with AS64512 in the path | ✘ rejected | 3.3 |
| IMP-LONG-PATH | 45.15.0.0/16 with 52 ASNs | ✘ rejected | 3.3 |
| IMP-DEFAULT | 0.0.0.0/0 from transit | ✘ rejected | 3.4 |
| IMP-PEER-LEAK | 45.21.0.0/16 with AS3356 behind the peer | ✘ rejected | 3.6 |
| IMP-IXP-LEAK | 45.31.0.0/16 with AS174 behind member-a | ✘ rejected | 3.6 |

**Customer filtering** (seen at transit)

| Check | Route | Expected | Lesson |
| --- | --- | :-: | :-: |
| CUST-IRR | 198.51.100.0/24, in the customer's IRR set | ✔ exported upstream | 3.5 |
| CUST-NOT-IRR | 45.40.0.0/16, not in the IRR set | ✘ rejected | 3.5 |

**Outbound policy** (seen at transit, peer and member-a)

| Check | What | Expected | Lesson |
| --- | --- | :-: | :-: |
| EXP-OWN-* (3) | your aggregate 203.0.113.0/24 everywhere | ✔ announced | 4.3 |
| EXP-CUST-IXP | the customer route at the IXP | ✔ announced | 4.4 |
| EXP-DNA-PEER | the customer asked "do not announce to AS64497" | ✘ not to the peer | 4.6 |
| LEAK-* (5) | transit, peer and IXP routes towards other upstreams | ✘ never | 4.4 |
| COMM-OWN / COMM-CUST | tags 64500:1:1 and 64500:1:3 on what transit receives | ✔ present | 4.2 |

One trap deserves a mention: the peer's route 45.20.0.0/16 carries a **forged customer tag** (64500:1:3). If it reaches transit, the router trusted a community it should have scrubbed on ingress (Lesson 3.7).

A **GAP** is a check that fails because of a documented platform limitation, listed in `labs/<vendor>/known-gaps.txt` (SR Linux has no RPKI origin validation, for example). Gaps do not count as failures.

## The ASPA lab

ROV checks who originated a route. A leak keeps the legitimate origin, so ROV cannot see it. **ASPA** lets every AS publish its list of providers in the RPKI. A router that knows its relationship with each neighbour (its BGP role) can then tell whether a path is plausible:

- **From a customer or a peer** (upstream verification), every hop must go *up*, from a customer to one of its providers.
- **From a provider** (downstream verification), the path may go up once and then down: no valleys.

The `aspa-bird`, `aspa-bird3` and `aspa-openbgpd` labs use a reduced topology (transit, peer, customer) with their own neighbours in `common/aspa/`:

| Check | Seen at | Route | AS path received | ASPA says | Expected |
| --- | --- | --- | --- | --- | :-: |
| A-T-VALID | customer | 45.80.0.0/16 | 64496 65540 | Valid | ✔ |
| A-T-VALLEY | customer | 45.81.0.0/16 | 64496 65541 65542 | Invalid: a valley | ✘ |
| A-T-UNKNOWN | customer | 45.82.0.0/16 | 64496 65549 65550 | Unknown | ✔ |
| A-P-VALID | customer | 45.70.0.0/16 | 64497 | Valid | ✔ |
| A-P-LEAK | customer | 45.71.0.0/16 | 64497 65545 65547 | Invalid: the peer leaks its provider's route | ✘ |
| A-C-VALID | transit | 45.60.0.0/16 | 64511 | Valid | ✔ |
| A-C-LEAK | transit | 45.61.0.0/16 | 64511 65536 65537 | Invalid: the customer leaks its other provider | ✘ |
| A-C-UNKNOWN | transit | 45.62.0.0/16 | 64511 65546 | Unknown | ✔ |

```bash
scripts/deploy.sh aspa-bird && sleep 30 && scripts/check.sh aspa-bird
```

The ASPA records live in `common/aspa/rpki/aspa.json`. `gen-aspa.py` turns them into the files the routers load, in the same formats rpki-client writes in production (`rpki-client -B` for BIRD, `aspa-set` for OpenBGPD). The lab does not use RTR for ASPA, on purpose: RTR version 2 is still an IETF draft, StayRTR 0.6 has no ASPA support, and implementations built on different draft revisions misread each other (BIRD 2.17 took StayRTR 0.5's ASPA records as withdrawals).

## MANRS mapping

| MANRS action | Where the labs exercise it |
| --- | --- |
| **NO-1 · Filtering** | IMP-\*, CUST-\*, EXP-\*, LEAK-\*, and the ASPA lab |
| **NO-2 · Anti-spoofing** | uRPF / ACL on the customer port, in every configuration (not checked automatically) |
| **NO-3 · Coordination** | Outside a lab's reach: PeeringDB, RIR and IRR contacts |
| **NO-4 · Global validation** | ROAs in `common/neighbors/rpki/vrps.json` (IMP-VALID, IMP-RPKI-INVALID) and ASPAs in `common/aspa/rpki/aspa.json` |

## Exercises

1. **Break it on purpose.** Remove the sanity call from the transit import policy, redeploy and re-run the checks. Which IMP-\* checks turn red?
2. **RPKI re-evaluation (Lesson 5.2).** Deploy with the validators stopped (`docker stop clab-ig-<vendor>-rpki1 clab-ig-<vendor>-rpki2`), let BGP converge, start them again and run the checks. Does IMP-RPKI-INVALID pass without a manual refresh? BIRD and OpenBGPD re-validate on their own; FRR 8.x needed `clear bgp * soft in`; GoBGP never re-validates and needs `gobgp neighbor all softresetin` (its `startup.sh` does it for you, try it without). OpenBGPD has its own twist: if it cannot reach a validator at start-up, it only retries after 600 s.
3. **Roles as a safety net (Lesson 4.5).** On FRR or BIRD, open the export filter towards the peer (accept everything) and re-run the checks. Transit routes still do not reach the peer: RFC 9234 roles and the OTC attribute stop them.
4. **Graceful shutdown (Lesson 7.1).** Drain the router with the maintenance command at the end of its configuration and watch the local preference of its routes on transit.
5. **Generate the customer filter.** Replace the placeholder customer list with real `bgpq4` output for an as-set of your choice.
6. **Leaks only ASPA sees (Lesson 5.5).** In an `aspa-*` lab, remove the ASPA rule and redeploy: A-T-VALLEY, A-P-LEAK and A-C-LEAK get through, and they would pass every other filter in the main labs.
7. **ASPA needs everyone.** Delete the ASPA of AS65536 from `aspa.json`, run `gen-aspa.py` and redeploy. A-C-LEAK becomes Unknown and is accepted: ASPA only protects you when the networks in the path publish theirs.
8. **Log before you reject.** As Lesson 5.5 recommends, replace the ASPA reject with a tag (BIRD: add a large community when `aspa_check_*` returns `ASPA_INVALID`; OpenBGPD: `match from ebgp avs invalid set { large-community 64500:666:1 }`) and find the would-be-rejected routes on the customer.

## Repository layout

```text
common/
  neighbors/       transit, peer, customer, member-a (FRR); rs1, rs2 (BIRD); ROAs
  aspa/            ASPA lab neighbours (FRR), ASPA records and gen-aspa.py
  images/          Dockerfiles / build scripts: BIRD, StayRTR, GoBGP, OpenBGPD, VyOS
  tests/check.py   the vendor-neutral checks (Python 3 standard library only)
labs/<vendor>/
  <vendor>.clab.yml   topology: same neighbours, vendor-specific router under test
  dut/                router configuration, lab edition
  known-gaps.txt      checks expected to fail for platform reasons (optional)
scripts/           deploy.sh, check.sh, destroy.sh
```

## Troubleshooting and lessons learned

Building the same policy on a dozen platforms taught us a few things, collected here so you do not have to rediscover them.

<details>
<summary><b>The lab uses real address space</b></summary>

The 45.x.0.0/16 prefixes are real address space, used only inside this isolated lab. Never connect the lab to the Internet.
</details>

<details>
<summary><b>Documentation filters are switched off</b></summary>

The lab itself is built on documentation prefixes and ASNs (RFC 5737, RFC 3849, RFC 5398), so every configuration ships with those filters commented out and marked `PRODUCTION`. Switch them on in a real network.
</details>

<details>
<summary><b>No TCP-MD5 / TCP-AO in the lab</b></summary>

TCP-MD5 needs kernel support (`CONFIG_TCP_MD5SIG`), and the OrbStack and Docker Desktop kernels do not have it. BIRD 2.17 refuses to start such a session ("Kernel does not support TCP MD5 signatures"); FRR silently runs it *without* MD5, which is worse. The lab sessions therefore run unauthenticated, and every configuration shows the production line as a comment (Lesson 2.2). To check your own host: `zcat /proc/config.gz 2>/dev/null | grep TCP_MD5 || grep TCP_MD5 /boot/config-$(uname -r)`.
</details>

<details>
<summary><b>GTSM</b></summary>

The FRR neighbours send TTL 255 (`ebgp-multihop 255`) and accept any TTL, so they work with routers with and without GTSM. The BIRD route servers enforce GTSM; SR Linux, which has no GTSM, reaches them with `multihop maximum-hops 255`.
</details>

<details>
<summary><b>RPKI timing and RTR versions</b></summary>

StayRTR 0.6 only speaks RTR version 1 unless started with `-protocol 2`. BIRD 2.17 offers version 2 first, is refused, and reconnects with version 1 on its next retry, so the first sync can take a minute (`retry keep 10` keeps it short). GoBGP does not re-run its import policy when ROAs arrive late, hence its `startup.sh`. OpenBGPD retries an unreachable validator only every 600 s and has no setting for it, hence its `start.sh`.
</details>

<details>
<summary><b>BIRD 2 and BIRD 3</b></summary>

BIRD 3 reads BIRD 2 configurations almost unchanged: the `bird3` lab uses the `bird` policy with two cosmetic fixes BIRD 3 warns about (a function now declares its return type with `-> bool`, and the template is no longer called `ebgp`, which is a keyword in BIRD 3). The difference is underneath: every protocol and table runs in its own thread, which matters on route servers with thousands of sessions. Distribution packages lag behind BIRD releases, so `common/images/bird3` builds the exact release from source, on amd64 and arm64.
</details>

<details>
<summary><b>SR Linux: apostrophes in comments</b></summary>

Containerlab loads `config.cli` as a single commit. The SR Linux CLI reads an apostrophe as the start of a quoted string, even inside a `#` comment: one unpaired apostrophe silently discards every line after it, with no error. Keep comments free of `'`.
</details>

<details>
<summary><b>Arista EOS: three route-map surprises</b></summary>

All three are worked around and documented in `labs/eos/dut/config.cfg`:

- AS-path regexes default to `regex-mode asn`, where each AS number is a single token, so `6451[2-9]` never matches. The lab uses `regex-mode string`.
- A `deny` inside a sub-route-map makes the parent entry "not match", and evaluation moves on to the next entry. Hence the explicit `deny 20`.
- `set large-community ... delete` is not applied in the order written relative to `additive`, so each session scrubs every informational tag except its own.
</details>

<details>
<summary><b>Images on Apple Silicon</b></summary>

`docker import` labels an image with the host architecture whatever it contains, so an x86 image looks like arm64 until it runs. cEOS x86 under emulation crashes its forwarding agent; VyOS amd64 hangs its configuration daemon; the vrnetlab base image is amd64-only and must be rebuilt natively for RouterOS.
</details>

<details>
<summary><b>Bind-mounted files and the IXP bridge</b></summary>

Editors that replace a file (`sed -i`, some `vim` settings) break Docker bind mounts: the container keeps the old file, so edit in place or redeploy. If the route-server sessions stay in `Connect`, Docker's `FORWARD DROP` policy is blocking the bridge; `deploy.sh` adds the `DOCKER-USER` rule that fixes it.
</details>

## References

The standards behind the policies and checks in these labs.

**BGP operations and route leaks**

| Document | Title | In the labs |
| --- | --- | --- |
| [RFC 4271](https://www.rfc-editor.org/rfc/rfc4271) | A Border Gateway Protocol 4 (BGP-4) | everywhere |
| [RFC 7454](https://www.rfc-editor.org/rfc/rfc7454) · BCP 194 | BGP Operations and Security | the policy as a whole |
| [RFC 8212](https://www.rfc-editor.org/rfc/rfc8212) | Default External BGP (EBGP) Route Propagation Behavior without Policies | default deny, Lesson 2.1 |
| [RFC 7908](https://www.rfc-editor.org/rfc/rfc7908) | Problem Definition and Classification of BGP Route Leaks | LEAK-\*, ASPA lab |
| [RFC 9234](https://www.rfc-editor.org/rfc/rfc9234) | Route Leak Prevention and Detection Using Roles in UPDATE and OPEN Messages | roles and OTC, Lesson 4.5 |

**Session protection**

| Document | Title | In the labs |
| --- | --- | --- |
| [RFC 5082](https://www.rfc-editor.org/rfc/rfc5082) | The Generalized TTL Security Mechanism (GTSM) | `ttl-security` on every session |
| [RFC 2385](https://www.rfc-editor.org/rfc/rfc2385) | Protection of BGP Sessions via the TCP MD5 Signature Option | production lines, Lesson 2.2 |
| [RFC 5925](https://www.rfc-editor.org/rfc/rfc5925) | The TCP Authentication Option | production lines, Lesson 2.2 |
| [RFC 5880](https://www.rfc-editor.org/rfc/rfc5880) | Bidirectional Forwarding Detection (BFD) | production lines, Lesson 2.4 |

**Bogons and special-purpose numbers**

| Document | Title | In the labs |
| --- | --- | --- |
| [RFC 6890](https://www.rfc-editor.org/rfc/rfc6890) · BCP 153 | Special-Purpose IP Address Registries | bogon lists |
| [RFC 1918](https://www.rfc-editor.org/rfc/rfc1918) | Address Allocation for Private Internets | IMP-BOGON |
| [RFC 6598](https://www.rfc-editor.org/rfc/rfc6598) | IANA-Reserved IPv4 Prefix for Shared Address Space | 100.64.0.0/10 |
| [RFC 7526](https://www.rfc-editor.org/rfc/rfc7526) | Deprecating the Anycast Prefix for 6to4 Relay Routers | 192.88.99.0/24, 2002::/16 |
| [RFC 6666](https://www.rfc-editor.org/rfc/rfc6666) | A Discard Prefix for IPv6 | 0100::/64 |
| [RFC 5737](https://www.rfc-editor.org/rfc/rfc5737) | IPv4 Address Blocks Reserved for Documentation | the lab's own addressing |
| [RFC 3849](https://www.rfc-editor.org/rfc/rfc3849) | IPv6 Address Prefix Reserved for Documentation | 2001:db8::/32 |
| [RFC 9637](https://www.rfc-editor.org/rfc/rfc9637) | Expanding the IPv6 Documentation Space | 3fff::/20 |
| [RFC 5398](https://www.rfc-editor.org/rfc/rfc5398) | Autonomous System (AS) Number Reservation for Documentation Use | the lab's own ASNs |
| [RFC 6996](https://www.rfc-editor.org/rfc/rfc6996) | Autonomous System (AS) Reservation for Private Use | IMP-BOGON-ASN |
| [RFC 7300](https://www.rfc-editor.org/rfc/rfc7300) | Reservation of Last Autonomous System (AS) Numbers | bogon ASNs |
| [RFC 6793](https://www.rfc-editor.org/rfc/rfc6793) | BGP Support for Four-Octet Autonomous System (AS) Number Space | AS_TRANS (23456) |
| [RFC 7607](https://www.rfc-editor.org/rfc/rfc7607) | Codification of AS 0 Processing | AS 0 |

**Communities**

| Document | Title | In the labs |
| --- | --- | --- |
| [RFC 1997](https://www.rfc-editor.org/rfc/rfc1997) | BGP Communities Attribute | standard communities |
| [RFC 8092](https://www.rfc-editor.org/rfc/rfc8092) | BGP Large Communities Attribute | the 64500:x:y scheme |
| [RFC 8195](https://www.rfc-editor.org/rfc/rfc8195) | Use of BGP Large Communities | informational and action communities, Lessons 4.2 and 4.6 |
| [RFC 7999](https://www.rfc-editor.org/rfc/rfc7999) | BLACKHOLE Community | RTBH, Lesson 6.4 |
| [RFC 8326](https://www.rfc-editor.org/rfc/rfc8326) | Graceful BGP Session Shutdown | GRACEFUL_SHUTDOWN, Lesson 7.1 |

**Internet Exchanges**

| Document | Title | In the labs |
| --- | --- | --- |
| [RFC 7947](https://www.rfc-editor.org/rfc/rfc7947) | Internet Exchange BGP Route Server | transparent route servers, Lesson 6.1 |
| [RFC 7948](https://www.rfc-editor.org/rfc/rfc7948) | Internet Exchange BGP Route Server Operations | Lesson 6.5 |

**RPKI and path validation**

| Document | Title | In the labs |
| --- | --- | --- |
| [RFC 6480](https://www.rfc-editor.org/rfc/rfc6480) | An Infrastructure to Support Secure Internet Routing | RPKI |
| [RFC 6811](https://www.rfc-editor.org/rfc/rfc6811) | BGP Prefix Origin Validation | ROV, Lesson 5.2 |
| [RFC 8481](https://www.rfc-editor.org/rfc/rfc8481) | Clarifications to BGP Origin Validation Based on RPKI | ROV behaviour |
| [RFC 8210](https://www.rfc-editor.org/rfc/rfc8210) | The RPKI to Router Protocol, Version 1 | the validators |
| [RFC 9319](https://www.rfc-editor.org/rfc/rfc9319) · BCP 185 | The Use of maxLength in the RPKI | ROAs, Lesson 5.1 |
| [draft-ietf-sidrops-aspa-profile](https://datatracker.ietf.org/doc/draft-ietf-sidrops-aspa-profile/) | A Profile for Autonomous System Provider Authorization | ASPA objects |
| [draft-ietf-sidrops-aspa-verification](https://datatracker.ietf.org/doc/draft-ietf-sidrops-aspa-verification/) | BGP AS_PATH Verification Based on ASPA Objects | ASPA lab, Lesson 5.5 |
| [draft-ietf-sidrops-8210bis](https://datatracker.ietf.org/doc/draft-ietf-sidrops-8210bis/) | The RPKI to Router Protocol, Version 2 | why the ASPA lab uses files |

**Anti-spoofing**

| Document | Title | In the labs |
| --- | --- | --- |
| [RFC 2827](https://www.rfc-editor.org/rfc/rfc2827) · BCP 38 | Network Ingress Filtering | customer port, Lesson 5.6 |
| [RFC 3704](https://www.rfc-editor.org/rfc/rfc3704) · BCP 84 | Ingress Filtering for Multihomed Networks | uRPF modes |
| [RFC 8704](https://www.rfc-editor.org/rfc/rfc8704) · BCP 84 | Enhanced Feasible-Path Unicast Reverse Path Forwarding | uRPF modes |

**Frameworks and tools**

- [MANRS for Network Operators](https://manrs.org/netops/) and [MANRS for IXPs](https://manrs.org/ixps/): the actions the labs are mapped to.
- [containerlab](https://containerlab.dev) and [vrnetlab](https://github.com/srl-labs/vrnetlab): the lab engine.
- [bgpq4](https://github.com/bgp/bgpq4): generates the customer filters from IRR data.
- [StayRTR](https://github.com/bgp/stayrtr) and [rpki-client](https://www.rpki-client.org): RTR server and relying-party software.

## License

MIT, see [LICENSE](LICENSE). Built by Victor Bolaños Guerra for the Interconnection Guidelines and Operational Best Practices course.
