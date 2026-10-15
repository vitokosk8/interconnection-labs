#!/bin/bash
# cRPD start-up: wait for the Junos management daemon, then load the lab
# configuration in "set" format. Run in the background by containerlab.
LOG=/tmp/lab-load.log
for i in $(seq 1 150); do
  cli -c "show version" >/dev/null 2>&1 && break
  sleep 2
done
# "load set" does not accept comment lines: strip them
grep -v '^[[:space:]]*#' /root/lab/config.set | grep -v '^[[:space:]]*$' > /tmp/lab.set

loaded() { cli -c "show configuration protocols bgp" 2>/dev/null | grep -q "group TRANSIT"; }

cli -c "configure private; load set /tmp/lab.set; commit and-quit" > "$LOG" 2>&1
if ! loaded; then
  # Fallback for cli builds that do not chain commands with ";"
  printf 'configure private\nload set /tmp/lab.set\ncommit and-quit\nexit\n' | cli >> "$LOG" 2>&1
fi
loaded && echo "lab configuration loaded" >> "$LOG" || echo "LOAD FAILED" >> "$LOG"
