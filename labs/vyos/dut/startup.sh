#!/bin/bash
# VyOS DUT start-up: wait until VyOS has finished booting, then load the
# lab configuration (set commands), commit and save. Runs in the
# background, started by containerlab. Result in /tmp/lab-load.log.
LOG=/tmp/lab-load.log
for i in $(seq 1 120); do
  systemctl is-active -q vyos-router && [ -e /opt/vyatta/etc/functions/script-template ] && break
  sleep 2
done
# Wait for the containerlab interfaces
for i in $(seq 1 60); do ip link show eth4 >/dev/null 2>&1 && break; sleep 1; done
# VyOS configures IPv6 on every interface (link-local, ::1 on lo): a
# container started with IPv6 disabled makes the whole commit fail.
sysctl -qw net.ipv6.conf.all.disable_ipv6=0 net.ipv6.conf.default.disable_ipv6=0
for i in lo eth1 eth2 eth3 eth4; do sysctl -qw net.ipv6.conf.$i.disable_ipv6=0; done
sleep 5
{
  echo '#!/bin/vbash'
  echo 'source /opt/vyatta/etc/functions/script-template'
  echo 'configure'
  grep '^set ' /root/lab/config.vyos
  echo 'commit'
  echo 'save'
  echo 'exit'
} > /tmp/lab.vbash
# VyOS may still be applying its own boot configuration ("Configuration
# system temporarily locked"), much longer under emulation (Rosetta):
# retry until the commit goes through and the saved config has our AS.
: > "$LOG"
for attempt in $(seq 1 30); do
  echo "=== attempt $attempt" >> "$LOG"
  sg vyattacfg -c "/bin/vbash /tmp/lab.vbash" >> "$LOG" 2>&1
  if grep -q "system-as 64500" /config/config.boot 2>/dev/null; then
    echo "lab configuration loaded" >> "$LOG"
    exit 0
  fi
  sleep 10
done
echo "LOAD FAILED - see the errors above" >> "$LOG"
