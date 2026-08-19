#!/usr/bin/env bash
set -euo pipefail

echo "=== identity ==="
id
echo "=== kernel ==="
uname -a
echo "=== architecture ==="
uname -m
echo "=== page size ==="
getconf PAGESIZE
echo "=== cpu features ==="
grep -m1 '^Features' /proc/cpuinfo
echo "=== memory ==="
free -h
echo "=== root filesystem ==="
df -h /
echo "=== userfaultfd setting ==="
cat /proc/sys/vm/unprivileged_userfaultfd 2>/dev/null || echo unavailable
echo "=== cloud-init ==="
cloud-init status --long || true
