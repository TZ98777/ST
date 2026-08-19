#!/usr/bin/env bash
set -uo pipefail

protected=/opt/stickytags/bin/stickytags-mechanism
baseline=/opt/stickytags/bin/unprotected-mechanism
boundary_trials=${1:-5}
granularity_trials=${2:-20}
persistence_iterations=${3:-1000}

run_report_case() {
    local variant=$1
    local binary=$2
    local suite=$3
    local kind=$4
    shift 4
    local output status result_line observed expected comparison comparison_status
    local fault_line fault_kind fault_si_code unexpected_sigsegv

    output=$(timeout --foreground --signal=KILL 30 "$binary" "$suite" "$kind" "$@" 2>&1)
    status=$?
    result_line=$(grep '^RESULT,' <<<"$output" | head -n 1)
    observed=$(sed -n 's/.*pass=\([0-9]\).*/\1/p' <<<"$result_line")
    fault_line=$(grep -E '^(MTE_FAULT|SIGSEGV_FAULT),' <<<"$output" | head -n 1)
    fault_kind=$(sed -n 's/.*kind=\([^,]*\).*/\1/p' <<<"$fault_line")
    fault_si_code=$(sed -n 's/.*si_code=\([^,]*\).*/\1/p' <<<"$fault_line")
    fault_kind=${fault_kind:-none}
    fault_si_code=${fault_si_code:-NA}
    if grep -q '^SIGSEGV_FAULT,' <<<"$output"; then
        unexpected_sigsegv=1
    else
        unexpected_sigsegv=0
    fi

    if [[ $suite == cycle && $variant == baseline ]]; then
        expected=0
    else
        expected=1
    fi

    if [[ -n $observed && $observed -eq $expected && $unexpected_sigsegv -eq 0 ]]; then
        comparison=1
        comparison_status=pass
    else
        comparison=0
        comparison_status=fail
    fi

    if [[ -n $result_line ]]; then
        printf 'RESULT,variant=%s,expected_mechanism_pass=%s,observed_mechanism_pass=%s,comparison_status=%s,comparison_pass=%s,exit_status=%s,fault_kind=%s,fault_si_code=%s,unexpected_sigsegv=%s,%s\n' \
            "$variant" "$expected" "${observed:-NA}" "$comparison_status" \
            "$comparison" "$status" "$fault_kind" "$fault_si_code" \
            "$unexpected_sigsegv" \
            "${result_line#RESULT,}"
    else
        printf 'RESULT,variant=%s,suite=%s,kind=%s,args=%s,expected_mechanism_pass=%s,observed_mechanism_pass=NA,comparison_status=fail,comparison_pass=0,exit_status=%s,fault_kind=%s,fault_si_code=%s,unexpected_sigsegv=%s\n' \
            "$variant" "$suite" "$kind" "$*" "$expected" "$status" \
            "$fault_kind" "$fault_si_code" "$unexpected_sigsegv"
    fi
}

run_fault_case() {
    local variant=$1
    local binary=$2
    local suite=$3
    local kind=$4
    local size_or_index=$5
    local param=$6
    local trial=$7
    local protected_expected_fault=$8
    local expected_fault output status mte_fault comparison layout_available
    local comparison_status unexpected_sigsegv fault_line fault_kind fault_si_code

    if [[ $variant == protected ]]; then
        expected_fault=$protected_expected_fault
    else
        expected_fault=0
    fi

    if [[ $suite == boundary ]]; then
        output=$(timeout --foreground --signal=KILL 30 "$binary" \
            boundary "$kind" "$size_or_index" "$param" 2>&1)
    else
        output=$(timeout --foreground --signal=KILL 30 "$binary" \
            granularity "$kind" "$param" 2>&1)
    fi
    status=$?

    fault_line=$(grep -E '^(MTE_FAULT|SIGSEGV_FAULT),' <<<"$output" | head -n 1)
    fault_kind=$(sed -n 's/.*kind=\([^,]*\).*/\1/p' <<<"$fault_line")
    fault_si_code=$(sed -n 's/.*si_code=\([^,]*\).*/\1/p' <<<"$fault_line")
    fault_kind=${fault_kind:-none}
    fault_si_code=${fault_si_code:-NA}
    if grep -Eq '^MTE_FAULT,.*kind=SEGV_MTE(AERR|SERR)(,|$)' <<<"$output"; then
        mte_fault=1
    else
        mte_fault=0
    fi
    if grep -q '^SIGSEGV_FAULT,' <<<"$output"; then
        unexpected_sigsegv=1
    else
        unexpected_sigsegv=0
    fi

    if grep -q 'layout=not_contiguous' <<<"$output"; then
        layout_available=0
    else
        layout_available=1
    fi

    if [[ $variant == baseline ]]; then
        if [[ $layout_available -eq 0 && $status -eq 3 && $mte_fault -eq 0 && $unexpected_sigsegv -eq 0 ]]; then
            comparison=NA
            comparison_status=skip
        elif [[ $mte_fault -eq 0 && $unexpected_sigsegv -eq 0 && $status -eq 0 ]]; then
            comparison=1
            comparison_status=pass
        else
            comparison=0
            comparison_status=fail
        fi
    else
        if [[ $expected_fault -eq 1 && $mte_fault -eq 1 && $unexpected_sigsegv -eq 0 ]]; then
            comparison=1
            comparison_status=pass
        elif [[ $expected_fault -eq 0 && $mte_fault -eq 0 && $unexpected_sigsegv -eq 0 && $status -eq 0 ]]; then
            comparison=1
            comparison_status=pass
        else
            comparison=0
            comparison_status=fail
        fi
    fi

    if [[ $suite == boundary ]]; then
        printf 'RESULT,variant=%s,suite=boundary,kind=%s,size=%s,slot=%s,trial=%s,expected_fault=%s,exit_status=%s,mte_fault=%s,fault_kind=%s,fault_si_code=%s,unexpected_sigsegv=%s,layout_available=%s,comparison_status=%s,comparison_pass=%s\n' \
            "$variant" "$kind" "$size_or_index" "$param" "$trial" \
            "$expected_fault" "$status" "$mte_fault" "$fault_kind" \
            "$fault_si_code" "$unexpected_sigsegv" "$layout_available" \
            "$comparison_status" "$comparison"
    else
        printf 'RESULT,variant=%s,suite=granularity,kind=%s,size=10,index=%s,trial=%s,expected_fault=%s,exit_status=%s,mte_fault=%s,fault_kind=%s,fault_si_code=%s,unexpected_sigsegv=%s,layout_available=%s,comparison_status=%s,comparison_pass=%s\n' \
            "$variant" "$kind" "$param" "$trial" "$expected_fault" \
            "$status" "$mte_fault" "$fault_kind" "$fault_si_code" \
            "$unexpected_sigsegv" "$layout_available" \
            "$comparison_status" "$comparison"
    fi
}

printf 'META,date=%s\n' "$(date --iso-8601=seconds)"
printf 'META,kernel=%s\n' "$(uname -a)"
grep -m1 '^Features' /proc/cpuinfo | sed 's/^/META,/'
sudo sysctl -w vm.unprivileged_userfaultfd=1 >/dev/null

for variant in protected baseline; do
    if [[ $variant == protected ]]; then
        binary=$protected
    else
        binary=$baseline
    fi

    for kind in heap stack; do
        for size in 16 32 64 128 256; do
            run_report_case "$variant" "$binary" cycle "$kind" "$size"
        done
    done

    for kind in heap stack; do
        for size in 16 32 64 128 256; do
            run_report_case "$variant" "$binary" persistence "$kind" \
                "$size" "$persistence_iterations"
        done
    done

    for kind in heap stack; do
        for size in 16 32 64 128; do
            for slot in $(seq 1 16); do
                if [[ $slot -eq 16 ]]; then
                    protected_expected_fault=0
                else
                    protected_expected_fault=1
                fi
                for trial in $(seq 1 "$boundary_trials"); do
                    run_fault_case "$variant" "$binary" boundary "$kind" \
                        "$size" "$slot" "$trial" "$protected_expected_fault"
                done
            done
        done
    done

    for kind in heap stack; do
        for index in 9 10 15 16 32; do
            if [[ $index -lt 16 ]]; then
                protected_expected_fault=0
            else
                protected_expected_fault=1
            fi
            for trial in $(seq 1 "$granularity_trials"); do
                run_fault_case "$variant" "$binary" granularity "$kind" 10 \
                    "$index" "$trial" "$protected_expected_fault"
            done
        done
    done
done
