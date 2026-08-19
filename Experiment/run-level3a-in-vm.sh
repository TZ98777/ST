#!/usr/bin/env bash
set -euo pipefail

lab_root=/home/brave/stickytags-lab
ssh_key=/home/brave/.ssh/stickytags_vm_ed25519
guest_script=/mnt/f/Paper/StickyTags/Experiment/run-level3a-guest.sh
raw_log="$lab_root/logs/stage9-level3a-results.txt"
summary_log="$lab_root/logs/stage9-level3a-summary.txt"
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
    variant = field("variant")
    suite = field("suite")
    kind = field("kind")
    key = variant "," suite "," kind
    total[key]++
    if (field("comparison_pass") == "1") {
        passed[key]++
    }
    if (suite == "boundary" || suite == "granularity") {
        fault_cases[variant]++
        if (field("expected_fault") == "1") {
            expected_faults[variant]++
        }
        if (field("mte_fault") == "1") {
            observed_faults[variant]++
        }
        if (field("layout_available") == "0") {
            layout_unavailable[variant]++
        }
    }
    if (suite == "cycle" && field("observed_mechanism_pass") == "1") {
        cycle_mechanism_pass[variant]++
    }
    if (suite == "persistence") {
        persistence_iterations[variant] += field("iterations")
        persistence_mismatches[variant] += field("mismatches")
    }
}
END {
    print "variant,suite,kind,cases,passed,pass_rate_percent"
    for (key in total) {
        printf "%s,%d,%d,%.1f\n", key, total[key], passed[key] + 0,
               100.0 * (passed[key] + 0) / total[key]
    }
    for (variant in fault_cases) {
        printf "metric,%s,fault_cases,%d\n", variant, fault_cases[variant]
        printf "metric,%s,expected_faults,%d\n", variant, expected_faults[variant] + 0
        printf "metric,%s,observed_faults,%d\n", variant, observed_faults[variant] + 0
        printf "metric,%s,layout_unavailable,%d\n", variant, layout_unavailable[variant] + 0
        printf "metric,%s,cycle_mechanism_passes,%d\n", variant, cycle_mechanism_pass[variant] + 0
        printf "metric,%s,persistence_iterations,%d\n", variant, persistence_iterations[variant] + 0
        printf "metric,%s,persistence_tag_mismatches,%d\n", variant, persistence_mismatches[variant] + 0
    }
}' "$raw_log" > "$summary_log"

cat "$summary_log"
