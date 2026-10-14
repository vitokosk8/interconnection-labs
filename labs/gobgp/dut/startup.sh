#!/bin/sh
# GoBGP DUT start-up tasks, run by containerlab once gobgpd is up.

# 1. Originate our own aggregates, tagged at origination (Lesson 4.3).
#    GoBGP keeps static routes outside the config file: they are added
#    through its API.
for i in $(seq 1 30); do gobgp global >/dev/null 2>&1 && break; sleep 1; done
gobgp global rib -a ipv4 add 203.0.113.0/24 origin igp large-community 64500:1:1
gobgp global rib -a ipv6 add 2001:db8:500::/40 origin igp large-community 64500:1:1

# 2. RPKI re-evaluation (Lesson 5.2). GoBGP runs the import policy when
#    a route arrives and does NOT re-run it when the validators deliver
#    new ROAs later. If BGP comes up before RPKI, Invalid routes accepted
#    in that window stay accepted. Wait for the ROAs, then re-apply the
#    import policy to everything already received (adj-RIB-in).
#    In production: run "gobgp neighbor all softresetin" after every
#    validator (re)connection, or periodically.
(
  for i in $(seq 1 120); do
    gobgp rpki table -a ipv4 2>/dev/null | grep -q '/' && break
    sleep 1
  done
  sleep 5
  gobgp neighbor all softresetin
) >/dev/null 2>&1 &
