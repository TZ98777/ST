#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/lab-env.sh"
lab_root=$STICKYTAGS_LAB_ROOT
ssh_key=$STICKYTAGS_SSH_KEY
remote="$STICKYTAGS_VM_USER@$STICKYTAGS_VM_HOST"
guest_script="$script_dir/run-mechanism-tests-guest.sh"
raw_log="$lab_root/logs/mechanism-test-results.txt"
summary_log="$lab_root/logs/mechanism-test-summary.txt"
boundary_trials=${1:-5}
granularity_trials=${2:-20}
persistence_iterations=${3:-1000}

for value_name in boundary_trials granularity_trials persistence_iterations; do
    value=${!value_name}
    if [[ ! $value =~ ^[1-9][0-9]*$ ]]; then
        echo "$value_name must be a positive integer: $value" >&2
        exit 64
    fi
done
if ((persistence_iterations < 2)); then
    echo "persistence_iterations must be at least 2." >&2
    exit 64
fi

ssh_options=(
    -i "$ssh_key"
    -p "$STICKYTAGS_VM_PORT"
    -o BatchMode=yes
    -o ConnectTimeout=60
    -o ServerAliveInterval=30
    -o StrictHostKeyChecking=no
)

ssh "${ssh_options[@]}" "$remote" \
    "bash -s -- '$boundary_trials' '$granularity_trials' '$persistence_iterations' '$STICKYTAGS_CASE_TIMEOUT'" \
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
    if (field("unexpected_sigsegv") == "1") {
        unexpected_sigsegv++
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
    printf "metric,unexpected_sigsegv,%d\n", unexpected_sigsegv
}' "$raw_log" > "$summary_log"

cat "$summary_log"

if grep -q 'pass=0' "$raw_log"; then
    echo "Mechanism validation contains failed cases." >&2
    exit 1
fi
