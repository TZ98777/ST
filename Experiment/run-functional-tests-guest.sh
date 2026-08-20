#!/usr/bin/env bash
set -uo pipefail

binary=/opt/stickytags/bin/stickytags-functional
repository_test=/opt/stickytags/bin/repository-test
failures=0

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
    local expected_status=$2
    local expected_mte_fault=$3
    shift 3
    local output status mte_fault unexpected_sigsegv pass
    echo "=== case: $name ==="
    output=$(timeout --foreground --signal=KILL 180 "$@" 2>&1)
    status=$?
    printf '%s\n' "$output"
    if grep -Eq 'kind=SEGV_MTE(AERR|SERR)' <<<"$output"; then
        mte_fault=1
    else
        mte_fault=0
    fi
    if grep -q 'caught SIGSEGV:' <<<"$output" && [[ $mte_fault -eq 0 ]]; then
        unexpected_sigsegv=1
    else
        unexpected_sigsegv=0
    fi
    if [[ $status -eq $expected_status && $mte_fault -eq $expected_mte_fault &&
          $unexpected_sigsegv -eq 0 ]]; then
        pass=1
    else
        pass=0
        failures=$((failures + 1))
    fi
    echo "EXIT_STATUS=$status"
    echo "EXPECTED_EXIT_STATUS=$expected_status"
    echo "MTE_FAULT=$mte_fault"
    echo "EXPECTED_MTE_FAULT=$expected_mte_fault"
    echo "PASS=$pass"
    echo
}

run_case normal 0 0 "$binary" normal
# The upstream program prints tagged addresses and intentionally returns 1.
# It is a layout probe, not an out-of-bounds protection test.
run_case upstream-layout-probe 1 0 "$repository_test" 1 2 3 4
run_case heap-oob 139 1 "$binary" heap-oob
run_case stack-oob 139 1 "$binary" stack-oob

echo "=== recent kernel messages ==="
sudo dmesg | tail -n 80

if [[ $failures -ne 0 ]]; then
    echo "Functional validation failed in $failures case(s)." >&2
    exit 1
fi
