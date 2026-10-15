# =====================================================================
# LAB EDITION - adapted from the reference configuration for the containerlab topology:
#   - containerlab eth1..eth4 = ether2..ether5 (ether1 is management)
#   - interface addresses added (section 0b)
#   - documentation-space rules stay DISABLED (the lab uses that space)
#   - no TCP-MD5 (container host kernels often lack it) and no BFD (the
#     lab neighbours do not run it): see the README
# =====================================================================
# =====================================================================
# Interconnection Guidelines and Operational Best Practices
# Reference configuration - MikroTik RouterOS v7 (instance-based BGP,
# /routing/bgp/instance). On older v7 releases without the instance
# menu, set as= and router-id= on the connections instead.
#
# DOCUMENTATION-ONLY RESOURCES (RFC 5737 / RFC 3849 / RFC 5398).
# Adapt before use. Validate in a lab (CHR) before production.
#
# Topology
#   AS64500 (us)        own: 203.0.113.0/24, 2001:db8:500::/40
#   ether2  Transit A   AS64496  198.51.100.1  / 2001:db8:100::1
#   ether3  Private peer AS64497 198.51.100.9
#   ether4  IXP LAN 192.0.2.0/24, us .50, RS1 .1 / RS2 .2 (AS64510)
#   ether5  Customer    AS64511  198.51.100.17, as-set AS64511:AS-CUSTOMERS
#
# Large community scheme (Unit 4)
#   64500:1:1 own   64500:1:2 transit   64500:1:3 customer
#   64500:1:4 private peer   64500:1:5 IXP route server
#   64500:10:ASN customer action: do not announce to ASN
# =====================================================================

# ---------------------------------------------------------------------
# 0. Interfaces facing other networks: no discovery, no MAC access
#    (Lesson 6.2 - keep the peering LAN clean)
# ---------------------------------------------------------------------
/interface list
add name=EXTERNAL comment="Interfaces facing other networks"
add name=INTERNAL comment="Management / internal interfaces"
/interface list member
add list=INTERNAL interface=ether1 comment="containerlab management"
add list=EXTERNAL interface=ether2
add list=EXTERNAL interface=ether3
add list=EXTERNAL interface=ether4
add list=EXTERNAL interface=ether5
/ip neighbor discovery-settings
set discover-interface-list=INTERNAL
/tool mac-server
set allowed-interface-list=INTERNAL
/tool mac-server mac-winbox
set allowed-interface-list=INTERNAL
/ip settings
set send-redirects=no
/ipv6 settings
set accept-router-advertisements=no


# ---------------------------------------------------------------------
# 0b. Interface addresses (lab)
# ---------------------------------------------------------------------
/interface bridge
add name=lo0 protocol-mode=none comment="Loopback"
/ip address
add address=198.51.100.2/30 interface=ether2 comment="Transit A"
add address=198.51.100.10/30 interface=ether3 comment="Peer AS64497"
add address=192.0.2.50/24 interface=ether4 comment="IXP LAN"
add address=198.51.100.18/30 interface=ether5 comment="Customer AS64511"
add address=203.0.113.1/32 interface=lo0 comment="Router ID"
/ipv6 address
add address=2001:db8:100::2/64 interface=ether2 advertise=no

# ---------------------------------------------------------------------
# 1. Own prefixes: static discard routes + origination list (Lesson 4.3)
# ---------------------------------------------------------------------
/ip route
add dst-address=203.0.113.0/24 blackhole comment="Own aggregate - origination anchor"
/ipv6 route
add dst-address=2001:db8:500::/40 blackhole comment="Own aggregate - origination anchor"
/ip firewall address-list
add list=bgp-networks address=203.0.113.0/24 comment="Announced by output.network"
/ipv6 firewall address-list
add list=bgp-networks address=2001:db8:500::/40 comment="Announced by output.network"

# ---------------------------------------------------------------------
# 2. Control plane: only configured neighbours reach TCP/179 (Lesson 2.2)
#    Place these BEFORE your existing input rules (place-before=...).
# ---------------------------------------------------------------------
/ip firewall address-list
add list=bgp-peers address=198.51.100.1  comment="Transit A"
add list=bgp-peers address=198.51.100.9  comment="Private peer AS64497"
add list=bgp-peers address=192.0.2.1     comment="IXP RS1"
add list=bgp-peers address=192.0.2.2     comment="IXP RS2"
add list=bgp-peers address=198.51.100.17 comment="Customer AS64511"
/ip firewall filter
add chain=input protocol=tcp dst-port=179 src-address-list=bgp-peers action=accept comment="BGP from configured neighbours"
add chain=input protocol=tcp dst-port=179 action=drop comment="BGP from anyone else"
/ipv6 firewall address-list
add list=bgp-peers address=2001:db8:100::1/128 comment="Transit A"
/ipv6 firewall filter
add chain=input protocol=tcp dst-port=179 src-address-list=bgp-peers action=accept comment="BGP from configured neighbours"
add chain=input protocol=tcp dst-port=179 action=drop comment="BGP from anyone else"

# ---------------------------------------------------------------------
# 3. Anti-spoofing on the single-homed customer edge (Lesson 5.6, MANRS NO-2)
#    Keep cust-as64511-src in sync with the customer's IRR data.
# ---------------------------------------------------------------------
/ip firewall address-list
add list=cust-as64511-src address=198.51.100.16/30 comment="Customer link"
# add list=cust-as64511-src address=CUSTOMER-PREFIX   (from the IRR data)
/ip firewall raw
add chain=prerouting in-interface=ether5 src-address-list=!cust-as64511-src action=drop comment="BCP38: customer AS64511 source validation"

# ---------------------------------------------------------------------
# 4. RPKI validators over RTR - two, independent (Lesson 5.2)
# ---------------------------------------------------------------------
/routing rpki
add group=rpki address=192.0.2.53 port=3323 comment="Validator 1 (e.g. Routinator)"
add group=rpki address=192.0.2.54 port=3323 comment="Validator 2 (e.g. rpki-client)"

# ---------------------------------------------------------------------
# 5. Filter objects
# ---------------------------------------------------------------------
/routing filter num-list
# Bogon ASNs (Lesson 3.3): AS0, AS_TRANS, private, reserved, private 32-bit
add list=bogon-asns range=0
add list=bogon-asns range=23456
add list=bogon-asns range=64512-65535
add list=bogon-asns range=65552-131071
add list=bogon-asns range=4200000000-4294967295
# Documentation ASNs - kept apart so the lab works (rule disabled below)
add list=doc-asns range=64496-64511
add list=doc-asns range=65536-65551
# Large transit networks that must never appear behind a peer or customer (Lesson 3.6)
add list=transit-asns range=174
add list=transit-asns range=701
add list=transit-asns range=1299
add list=transit-asns range=2914
add list=transit-asns range=3257
add list=transit-asns range=3320
add list=transit-asns range=3356
add list=transit-asns range=3491
add list=transit-asns range=5511
add list=transit-asns range=6453
add list=transit-asns range=6461
add list=transit-asns range=6762
add list=transit-asns range=6830
add list=transit-asns range=7018
add list=transit-asns range=12956

/routing filter community-large-list
# Our informational communities: scrubbed on ingress (Lesson 3.7)
add list=own-info communities=64500:1:1
add list=own-info communities=64500:1:2
add list=own-info communities=64500:1:3
add list=own-info communities=64500:1:4
add list=own-info communities=64500:1:5

# ---------------------------------------------------------------------
# 6. Inbound: shared sanity chain (Lessons 3.2-3.4)
#    Rules run in the order they are added. The chain ends with return.
# ---------------------------------------------------------------------
/routing filter rule
add chain=sanity-in rule="if (afi ipv4 && (dst-len < 8 || dst-len > 24)) { reject }" comment="IPv4 length /8-/24"
add chain=sanity-in rule="if (afi ipv6 && (dst-len < 16 || dst-len > 48)) { reject }" comment="IPv6 length /16-/48"
add chain=sanity-in rule="if (afi ipv4 && (dst in 0.0.0.0/8 || dst in 10.0.0.0/8 || dst in 100.64.0.0/10 || dst in 127.0.0.0/8 || dst in 169.254.0.0/16 || dst in 172.16.0.0/12)) { reject }" comment="IPv4 bogons (1/2)"
add chain=sanity-in rule="if (afi ipv4 && (dst in 192.0.0.0/24 || dst in 192.168.0.0/16 || dst in 198.18.0.0/15 || dst in 224.0.0.0/4 || dst in 240.0.0.0/4)) { reject }" comment="IPv4 bogons (2/2)"
add chain=sanity-in rule="if (afi ipv4 && (dst in 192.0.2.0/24 || dst in 198.51.100.0/24 || dst in 203.0.113.0/24)) { reject }" disabled=yes comment="PRODUCTION: enable - IPv4 documentation space"
add chain=sanity-in rule="if (afi ipv6 && (dst in ::/3 || dst in 4000::/2 || dst in 8000::/1)) { reject }" comment="IPv6 outside 2000::/3"
add chain=sanity-in rule="if (afi ipv6 && (dst in 2001:2::/48 || dst in 2001:10::/28 || dst in 2002::/16 || dst in 3ffe::/16)) { reject }" comment="IPv6 bogons"
add chain=sanity-in rule="if (afi ipv6 && (dst in 2001:db8::/32 || dst in 3fff::/20)) { reject }" disabled=yes comment="PRODUCTION: enable - IPv6 documentation space"
add chain=sanity-in rule="if (bgp-as-path [[:bogon-asns:]]) { reject }" comment="Bogon ASN in path"
add chain=sanity-in rule="if (bgp-as-path [[:doc-asns:]]) { reject }" disabled=yes comment="PRODUCTION: enable - documentation ASNs"
add chain=sanity-in rule="if (bgp-path-len > 50) { reject }" comment="AS path too long"
add chain=sanity-in rule="if (afi ipv4 && dst in 203.0.113.0/24) { reject }" comment="Own IPv4 space from outside"
add chain=sanity-in rule="if (afi ipv6 && dst in 2001:db8:500::/40) { reject }" comment="Own IPv6 space from outside"
add chain=sanity-in rule="if (afi ipv4 && dst in 192.0.2.0/24) { reject }" comment="IXP peering LAN"
add chain=sanity-in rule="rpki-verify rpki" comment="RPKI ROV (Lesson 5.2)"
add chain=sanity-in rule="if (rpki invalid) { reject }" comment="Reject RPKI Invalid"
add chain=sanity-in rule="delete bgp-large-communities own-info" comment="Scrub our informational communities"
add chain=sanity-in rule="return"

# ---------------------------------------------------------------------
# 7. Inbound per relationship (Lessons 3.5, 3.6, 4.2, 7.1)
#    Order inside each chain: sanity -> session checks -> tag + LP ->
#    honour GRACEFUL_SHUTDOWN -> accept.
# ---------------------------------------------------------------------
add chain=transit-in rule="jump sanity-in"
add chain=transit-in rule="set bgp-local-pref 100; append bgp-large-communities 64500:1:2"
add chain=transit-in rule="if (bgp-communities includes 65535:0) { set bgp-local-pref 0 }" comment="Honour GRACEFUL_SHUTDOWN"
add chain=transit-in rule="accept"

add chain=peer-in rule="jump sanity-in"
add chain=peer-in rule="if (bgp-as-path [[:transit-asns:]]) { reject }" comment="Transit ASN behind a peer = leak"
add chain=peer-in rule="set bgp-local-pref 250; append bgp-large-communities 64500:1:4"
add chain=peer-in rule="if (bgp-communities includes 65535:0) { set bgp-local-pref 0 }"
add chain=peer-in rule="accept"

add chain=ixp-rs-in rule="jump sanity-in"
add chain=ixp-rs-in rule="if (bgp-as-path [[:transit-asns:]]) { reject }"
add chain=ixp-rs-in rule="set bgp-local-pref 200; append bgp-large-communities 64500:1:5"
add chain=ixp-rs-in rule="if (bgp-communities includes 65535:0) { set bgp-local-pref 0 }"
add chain=ixp-rs-in rule="accept"

# Customer: the IRR prefix chains CUST-AS64511-V4 / -V6 are generated by
#   bgpq4 -K7 -4 -A -m 24 -l CUST-AS64511 AS64511:AS-CUSTOMERS
#   bgpq4 -K7 -6 -A -m 48 -l CUST-AS64511 AS64511:AS-CUSTOMERS
# and contain only accept rules. Anything not matched is rejected below.
# PLACEHOLDER IRR chains - replace with the bgpq4 output
add chain=CUST-AS64511-V4 rule="if (dst == 198.51.100.0/24) { accept }"
add chain=CUST-AS64511-V6 rule="if (dst in 2001:db8:6400::/40 && dst-len <= 48) { accept }"

add chain=cust-as64511-in rule="jump sanity-in"
add chain=cust-as64511-in rule="if (bgp-as-path [[:transit-asns:]]) { reject }"
add chain=cust-as64511-in rule="set bgp-local-pref 300; append bgp-large-communities 64500:1:3"
add chain=cust-as64511-in rule="if (bgp-communities includes 65535:0) { set bgp-local-pref 0 }"
add chain=cust-as64511-in rule="if (afi ipv4) { jump CUST-AS64511-V4 }"
add chain=cust-as64511-in rule="if (afi ipv6) { jump CUST-AS64511-V6 }"
add chain=cust-as64511-in rule="reject" comment="Not in customer IRR set (MANRS NO-1)"

# ---------------------------------------------------------------------
# 8. Outbound (Lessons 4.4, 4.6, 6.4, 7.1)
# ---------------------------------------------------------------------
add chain=upstream-out rule="append bgp-communities 65535:0" disabled=yes comment="MAINT: enable to drain the router (GRACEFUL_SHUTDOWN)"
add chain=upstream-out rule="if (bgp-network && ((afi ipv4 && dst-len == 32) || (afi ipv6 && dst-len == 128))) { append bgp-communities 65535:666,65535:65281; accept }" comment="RTBH: own host routes only (RFC 7999)"
add chain=upstream-out rule="if (bgp-large-communities includes 64500:10:64496 && bgp-output-remote-as == 64496) { reject }" comment="Customer action: do not announce to AS64496"
add chain=upstream-out rule="if (bgp-large-communities includes 64500:10:64497 && bgp-output-remote-as == 64497) { reject }" comment="Customer action: do not announce to AS64497"
add chain=upstream-out rule="if (bgp-large-communities includes 64500:10:64510 && bgp-output-remote-as == 64510) { reject }" comment="Customer action: do not announce to AS64510"
add chain=upstream-out rule="if (bgp-network) { append bgp-large-communities 64500:1:1; accept }" comment="Own prefixes"
add chain=upstream-out rule="if (bgp-large-communities includes 64500:1:3) { accept }" comment="Customer routes"
add chain=upstream-out rule="reject" comment="Never export transit or peer routes (MANRS NO-1)"

add chain=customer-out rule="accept" comment="Full table to customer (or restrict to default per contract)"

# ---------------------------------------------------------------------
# 9. BFD on point-to-point links (Lesson 2.4)
# ---------------------------------------------------------------------
# PRODUCTION: uncomment (the lab neighbours run no BFD)
# /routing bfd configuration
# add interfaces=ether2,ether3,ether5 min-rx=300ms min-tx=300ms multiplier=3

# ---------------------------------------------------------------------
# 10. BGP instance and sessions (Lessons 2.1-2.5, 4.5, 6.1)
#     Lab: no tcp-md5-key / use-bfd. Production: add
#       tcp-md5-key=KEY use-bfd=yes   (Lesson 2.2, 2.4)
#     Every connection: explicit input.filter AND output.filter-chain,
#     a BGP role, a prefix limit, GTSM (local.ttl/remote.ttl 255) on
#     directly connected eBGP sessions.
# ---------------------------------------------------------------------
/routing bgp instance
add name=main as=64500 router-id=203.0.113.1

/routing bgp connection
add name=transit-a-v4 instance=main afi=ip \
    remote.address=198.51.100.1 remote.as=64496 local.address=198.51.100.2 \
    local.role=ebgp-customer local.ttl=255 remote.ttl=255 \
    input.filter=transit-in input.limit-process-routes-ipv4=1100000 \
    output.filter-chain=upstream-out output.network=bgp-networks \
    comment="Transit A - IPv4"
add name=transit-a-v6 instance=main afi=ipv6 \
    remote.address=2001:db8:100::1 remote.as=64496 local.address=2001:db8:100::2 \
    local.role=ebgp-customer local.ttl=255 remote.ttl=255 \
    input.filter=transit-in input.limit-process-routes-ipv6=250000 \
    output.filter-chain=upstream-out output.network=bgp-networks \
    comment="Transit A - IPv6"
add name=peer-as64497-v4 instance=main afi=ip \
    remote.address=198.51.100.9 remote.as=64497 local.address=198.51.100.10 \
    local.role=ebgp-peer local.ttl=255 remote.ttl=255 \
    input.filter=peer-in input.limit-process-routes-ipv4=1200 \
    output.filter-chain=upstream-out output.network=bgp-networks \
    comment="Private peer AS64497 - limit from PeeringDB + 20%"
add name=ixp-rs1-v4 instance=main afi=ip \
    remote.address=192.0.2.1 remote.as=64510 local.address=192.0.2.50 \
    local.role=ebgp-rs-client local.ttl=255 remote.ttl=255 \
    input.filter=ixp-rs-in input.limit-process-routes-ipv4=250000 \
    output.filter-chain=upstream-out output.network=bgp-networks \
    comment="IXP route server 1"
add name=ixp-rs2-v4 instance=main afi=ip \
    remote.address=192.0.2.2 remote.as=64510 local.address=192.0.2.50 \
    local.role=ebgp-rs-client local.ttl=255 remote.ttl=255 \
    input.filter=ixp-rs-in input.limit-process-routes-ipv4=250000 \
    output.filter-chain=upstream-out output.network=bgp-networks \
    comment="IXP route server 2"
add name=cust-as64511-v4 instance=main afi=ip \
    remote.address=198.51.100.17 remote.as=64511 local.address=198.51.100.18 \
    local.role=ebgp-provider local.ttl=255 remote.ttl=255 \
    input.filter=cust-as64511-in input.limit-process-routes-ipv4=50 \
    output.filter-chain=customer-out output.network=bgp-networks \
    comment="Customer AS64511 - limit from generated prefix list"

# ---------------------------------------------------------------------
# 11. Logging for monitoring (Lesson 7.3)
# ---------------------------------------------------------------------
/system logging
add topics=bgp action=memory
