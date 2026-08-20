#!/usr/bin/env bash
set -uo pipefail

protected=/opt/stickytags/bin/stickytags-functional
baseline=/opt/stickytags/bin/unprotected-functional
trials=${1:-20}
case_timeout=${2:-120}
if [[ ! $trials =~ ^[1-9][0-9]*$ ]]; then
    echo "trials must be a positive integer: $trials" >&2
    exit 64
fi
if [[ ! $case_timeout =~ ^[1-9][0-9]*$ ]]; then
    echo "case_timeout must be a positive integer: $case_timeout" >&2
    exit 64
fi

printf 'variant,case,trial,exit_status,mte_fault,fault_kind,fault_si_code,unexpected_sigsegv,expected_mte_fault,pass\n'

run_one() {
    local variant=$1
    local binary=$2
    local case_name=$3
    local trial=$4
    local output status fault fault_kind fault_si_code unexpected_sigsegv
    local expected_fault expected_status pass

    output=$(timeout --foreground --signal=KILL "$case_timeout" \
        "$binary" "$case_name" 2>&1)
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
    if [[ $variant == protected && $case_name != normal ]]; then
        expected_fault=1
        expected_status=139
    else
        expected_fault=0
        expected_status=0
    fi
    if [[ $status -eq $expected_status && $fault -eq $expected_fault &&
          $unexpected_sigsegv -eq 0 ]]; then
        pass=1
    else
        pass=0
    fi
    printf '%s,%s,%d,%d,%d,%s,%s,%s,%s,%s\n' \
        "$variant" "$case_name" "$trial" "$status" "$fault" \
        "$fault_kind" "$fault_si_code" "$unexpected_sigsegv" \
        "$expected_fault" "$pass"
}

run_one baseline "$baseline" normal 1
run_one protected "$protected" normal 1

for case_name in heap-oob stack-oob; do
    for trial in $(seq 1 "$trials"); do
        run_one baseline "$baseline" "$case_name" "$trial"
        run_one protected "$protected" "$case_name" "$trial"
    done
done
