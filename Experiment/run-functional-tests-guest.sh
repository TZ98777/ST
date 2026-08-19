#!/usr/bin/env bash
set -uo pipefail

binary=/opt/stickytags/bin/stickytags-functional
repository_test=/opt/stickytags/bin/repository-test

echo "=== guest environment ==="
date --iso-8601=seconds
uname -a
getconf PAGESIZE
grep -m 1 '^Features' /proc/cpuinfo
sudo sysctl -w vm.unprivileged_userfaultfd=1
printf 'tagged address control before tests: '
cat /proc/self/status | grep -E '^(Threads|SigQ)' | tr '\n' ' '
echo

run_case() {
    local name=$1
    shift
    echo "=== case: $name ==="
    timeout --foreground --signal=KILL 180 "$@"
    local status=$?
    echo "EXIT_STATUS=$status"
    echo
}

run_case normal "$binary" normal
run_case repository-test "$repository_test" 1 2 3 4
run_case heap-oob "$binary" heap-oob
run_case stack-oob "$binary" stack-oob

echo "=== recent kernel messages ==="
sudo dmesg | tail -n 80
