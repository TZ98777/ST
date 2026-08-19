#!/usr/bin/env bash
set -uo pipefail

protected=/opt/stickytags/bin/stickytags-functional
baseline=/opt/stickytags/bin/unprotected-functional
trials=${1:-20}

printf 'variant,case,trial,exit_status,mte_fault\n'

run_one() {
    local variant=$1
    local binary=$2
    local case_name=$3
    local trial=$4
    local output status fault

    output=$(timeout --foreground --signal=KILL 15 "$binary" "$case_name" 2>&1)
    status=$?
    if grep -q 'SEGV_MTE' <<<"$output"; then
        fault=1
    else
        fault=0
    fi
    printf '%s,%s,%d,%d,%d\n' \
        "$variant" "$case_name" "$trial" "$status" "$fault"
}

run_one baseline "$baseline" normal 1
run_one protected "$protected" normal 1

for case_name in heap-oob stack-oob; do
    for trial in $(seq 1 "$trials"); do
        run_one baseline "$baseline" "$case_name" "$trial"
        run_one protected "$protected" "$case_name" "$trial"
    done
done
