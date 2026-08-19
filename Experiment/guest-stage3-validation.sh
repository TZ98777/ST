#!/usr/bin/env bash
set -euo pipefail

OUT=/home/brave/stickytags-stage3-validation.txt
exec >"$OUT" 2>&1

echo "StickyTags ARM64/MTE environment validation"
date --iso-8601=seconds
echo
/usr/bin/bash /home/brave/guest-environment-check.sh
echo
echo "=== MTE syscall probe ==="
/home/brave/mte-probe
echo
echo "=== enable userfaultfd ==="
sudo /sbin/sysctl -w vm.unprivileged_userfaultfd=1
printf 'effective_value='
cat /proc/sys/vm/unprivileged_userfaultfd
