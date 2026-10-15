#!/bin/bash
# OpenBGPD DUT start-up, run as the container command by containerlab.
mkdir -p /run/openbgpd

# 1. containerlab adds the interface addresses right after the container
#    starts: wait for them.
for i in $(seq 1 30); do ip -4 addr show | grep -q 203.0.113.1 && break; sleep 1; done

# 2. RPKI (Lesson 5.2). If bgpd cannot reach a validator at start-up it
#    retries only every 600 s, and the rtr block has no retry setting:
#    until then every route is NotFound and RPKI Invalids are accepted.
#    Start bgpd once at least one validator answers (60 s at most).
for i in $(seq 1 60); do
  for v in 192.0.2.53 192.0.2.54; do
    (exec 3<>"/dev/tcp/$v/3323") 2>/dev/null && break 2
  done
  sleep 1
done

exec bgpd -d -f /etc/bgpd.conf
