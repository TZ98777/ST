#!/usr/bin/env bash
set -euo pipefail

lab_root=/home/brave/stickytags-lab
ssh_key=/home/brave/.ssh/stickytags_vm_ed25519
guest_script=/mnt/f/Paper/StickyTags/Experiment/run-level2-guest.sh
raw_log="$lab_root/logs/stage8-level2-results.txt"
summary_log="$lab_root/logs/stage8-level2-summary.txt"
boundary_trials=${1:-5}
granularity_trials=${2:-20}
persistence_iterations=${3:-1000}

ssh_options=(
    -i "$ssh_key"
    -p 2222
    -o BatchMode=yes
    -o ConnectTimeout=60
    -o ServerAliveInterval=30
    -o StrictHostKeyChecking=no
)

ssh "${ssh_options[@]}" brave@127.0.0.1 \
    "bash -s -- '$boundary_trials' '$granularity_trials' '$persistence_iterations'" \
    < "$guest_script" > "$raw_log"

awk -F, '
function field(name,    i, kv) {
    for (i = 1; i <= NF; ++i) {
        split($i, kv, "=")
        if (kv[1] == name) {
            return kv[2]
        }
    }
    return ""
}
$1 == "RESULT" {
    suite = field("suite")
    kind = field("kind")
    key = suite "," kind
    total[key]++
    if (field("pass") == "1") {
        passed[key]++
    }
    if (suite == "cycle") {
        cycle_objects += field("objects")
    }
    if (suite == "persistence") {
        persist_iterations += field("iterations")
        persist_reuses += field("reuses")
        persist_mismatches += field("mismatches")
    }
    if (suite == "boundary" || suite == "granularity") {
        fault_cases++
        if (field("expected_fault") == "1") {
            expected_faults++
        }
        if (field("mte_fault") == "1") {
            observed_faults++
        }
    }
}
END {
    print "suite,kind,cases,passed,pass_rate_percent"
    for (key in total) {
        printf "%s,%d,%d,%.1f\n", key, total[key], passed[key] + 0,
               100.0 * (passed[key] + 0) / total[key]
    }
    printf "metric,cycle_objects,%d\n", cycle_objects
    printf "metric,persistence_iterations,%d\n", persist_iterations
    printf "metric,persistence_reuses,%d\n", persist_reuses
    printf "metric,persistence_tag_mismatches,%d\n", persist_mismatches
    printf "metric,fault_cases,%d\n", fault_cases
    printf "metric,expected_faults,%d\n", expected_faults
    printf "metric,observed_faults,%d\n", observed_faults
}' "$raw_log" > "$summary_log"

cat "$summary_log"
