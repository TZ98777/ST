#!/usr/bin/env bash
set -uo pipefail

protected=/opt/stickytags/bin/stickytags-functional
baseline=/opt/stickytags/bin/unprotected-functional
trials=${1:-20}

printf 'variant,case,trial,exit_status,mte_fault,fault_kind,fault_si_code,unexpected_sigsegv\n'

run_one() {
    local variant=$1
    local binary=$2
    local case_name=$3
    local trial=$4
    local output status fault fault_kind fault_si_code unexpected_sigsegv

    output=$(timeout --foreground --signal=KILL 15 "$binary" "$case_name" 2>&1)
    status=$?
    fault_kind=$(sed -n 's/.*kind=\(SEGV_MTE[A-Z]*\).*/\1/p' <<<"$output" | head -n 1)
    fault_si_code=$(sed -n 's/.*si_code=\([-0-9]*\).*/\1/p' <<<"$output" | head -n 1)
    fault_kind=${fault_kind:-none}
    fault_si_code=${fault_si_code:-NA}
    if grep -Eq 'kind=SEGV_MTE(AERR|SERR)' <<<"$output"; then
        fault=1
    else
        fault=0
    fi
    if grep -q 'caught SIGSEGV:' <<<"$output" && [[ $fault -eq 0 ]]; then
        unexpected_sigsegv=1
    else
        unexpected_sigsegv=0
    fi
    printf '%s,%s,%d,%d,%d,%s,%s,%s\n' \
        "$variant" "$case_name" "$trial" "$status" "$fault" \
        "$fault_kind" "$fault_si_code" "$unexpected_sigsegv"
}

run_one baseline "$baseline" normal 1
run_one protected "$protected" normal 1

for case_name in heap-oob stack-oob; do
    for trial in $(seq 1 "$trials"); do
        run_one baseline "$baseline" "$case_name" "$trial"
        run_one protected "$protected" "$case_name" "$trial"
    done
done
