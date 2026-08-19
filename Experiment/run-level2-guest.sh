#!/usr/bin/env bash
set -uo pipefail

binary=/opt/stickytags/bin/stickytags-level2
boundary_trials=${1:-5}
granularity_trials=${2:-20}
persistence_iterations=${3:-1000}

run_report_case() {
    local suite=$1
    local kind=$2
    shift 2
    local output status
    output=$(timeout --foreground --signal=KILL 30 "$binary" "$suite" "$kind" "$@" 2>&1)
    status=$?
    if grep -q '^RESULT,' <<<"$output"; then
        grep '^RESULT,' <<<"$output"
    else
        printf 'RESULT,suite=%s,kind=%s,args=%s,exit_status=%d,pass=0\n' \
            "$suite" "$kind" "$*" "$status"
    fi
}

run_fault_case() {
    local suite=$1
    local kind=$2
    local size_or_index=$3
    local param=$4
    local trial=$5
    local expected_fault=$6
    local output status mte_fault pass

    if [[ $suite == boundary ]]; then
        output=$(timeout --foreground --signal=KILL 30 "$binary" \
            boundary "$kind" "$size_or_index" "$param" 2>&1)
    else
        output=$(timeout --foreground --signal=KILL 30 "$binary" \
            granularity "$kind" "$param" 2>&1)
    fi
    status=$?
    if grep -q '^MTE_FAULT,' <<<"$output"; then
        mte_fault=1
    else
        mte_fault=0
    fi
    if [[ $expected_fault -eq 1 && $mte_fault -eq 1 ]]; then
        pass=1
    elif [[ $expected_fault -eq 0 && $mte_fault -eq 0 && $status -eq 0 ]]; then
        pass=1
    else
        pass=0
    fi
    if [[ $suite == boundary ]]; then
        printf 'RESULT,suite=boundary,kind=%s,size=%s,slot=%s,trial=%s,expected_fault=%s,exit_status=%s,mte_fault=%s,pass=%s\n' \
            "$kind" "$size_or_index" "$param" "$trial" "$expected_fault" \
            "$status" "$mte_fault" "$pass"
    else
        printf 'RESULT,suite=granularity,kind=%s,size=10,index=%s,trial=%s,expected_fault=%s,exit_status=%s,mte_fault=%s,pass=%s\n' \
            "$kind" "$param" "$trial" "$expected_fault" "$status" \
            "$mte_fault" "$pass"
    fi
}

printf 'META,date=%s\n' "$(date --iso-8601=seconds)"
printf 'META,kernel=%s\n' "$(uname -a)"
grep -m1 '^Features' /proc/cpuinfo | sed 's/^/META,/'
sudo sysctl -w vm.unprivileged_userfaultfd=1 >/dev/null

for kind in heap stack; do
    for size in 16 32 64 128 256; do
        run_report_case cycle "$kind" "$size"
    done
done

for kind in heap stack; do
    for size in 16 32 64 128 256; do
        run_report_case persistence "$kind" "$size" "$persistence_iterations"
    done
done

for kind in heap stack; do
    for size in 16 32 64 128; do
        for slot in $(seq 1 16); do
            if [[ $slot -eq 16 ]]; then
                expected_fault=0
            else
                expected_fault=1
            fi
            for trial in $(seq 1 "$boundary_trials"); do
                run_fault_case boundary "$kind" "$size" "$slot" "$trial" \
                    "$expected_fault"
            done
        done
    done
done

for kind in heap stack; do
    for index in 9 10 15 16 32; do
        if [[ $index -lt 16 ]]; then
            expected_fault=0
        else
            expected_fault=1
        fi
        for trial in $(seq 1 "$granularity_trials"); do
            run_fault_case granularity "$kind" 10 "$index" "$trial" \
                "$expected_fault"
        done
    done
done
