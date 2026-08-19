#!/usr/bin/env bash
set -uo pipefail

protected=/opt/stickytags/bin/stickytags-functional
baseline=/opt/stickytags/bin/unprotected-functional

echo "=== representative baseline/protected comparison ==="
date --iso-8601=seconds
uname -a
grep -m1 '^Features' /proc/cpuinfo
echo

for variant in baseline protected; do
    if [[ $variant == baseline ]]; then
        binary=$baseline
    else
        binary=$protected
    fi
    for case_name in normal heap-oob stack-oob; do
        echo "=== variant=$variant case=$case_name ==="
        timeout --foreground --signal=KILL 15 "$binary" "$case_name"
        status=$?
        echo "EXIT_STATUS=$status"
        echo
    done
done
