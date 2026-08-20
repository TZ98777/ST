#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/lab-env.sh"
lab_root=$STICKYTAGS_LAB_ROOT
ssh_key=$STICKYTAGS_SSH_KEY
remote="$STICKYTAGS_VM_USER@$STICKYTAGS_VM_HOST"
guest_script="$script_dir/run-protected-baseline-guest.sh"
raw_log="$lab_root/logs/protected-baseline-results.txt"
summary_log="$lab_root/logs/protected-baseline-summary.txt"
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
    variant = field("variant")
    suite = field("suite")
    kind = field("kind")
    key = variant "," suite "," kind
    total[key]++
    if (field("comparison_status") == "pass") {
        passed[key]++
    } else if (field("comparison_status") == "skip") {
        skipped[key]++
    } else {
        failed[key]++
    }
    if (field("unexpected_sigsegv") == "1") {
        unexpected_sigsegv[variant]++
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
    print "variant,suite,kind,cases,passed,skipped,failed,pass_rate_percent"
    for (key in total) {
        executed = total[key] - (skipped[key] + 0)
        rate = executed > 0 ? sprintf("%.1f", 100.0 * (passed[key] + 0) / executed) : "NA"
        printf "%s,%d,%d,%d,%d,%s\n", key, total[key], passed[key] + 0,
               skipped[key] + 0, failed[key] + 0, rate
    }
    for (variant in fault_cases) {
        printf "metric,%s,fault_cases,%d\n", variant, fault_cases[variant]
        printf "metric,%s,expected_faults,%d\n", variant, expected_faults[variant] + 0
        printf "metric,%s,observed_faults,%d\n", variant, observed_faults[variant] + 0
        printf "metric,%s,layout_unavailable,%d\n", variant, layout_unavailable[variant] + 0
        printf "metric,%s,unexpected_sigsegv,%d\n", variant, unexpected_sigsegv[variant] + 0
        printf "metric,%s,cycle_mechanism_passes,%d\n", variant, cycle_mechanism_pass[variant] + 0
        printf "metric,%s,persistence_iterations,%d\n", variant, persistence_iterations[variant] + 0
        printf "metric,%s,persistence_tag_mismatches,%d\n", variant, persistence_mismatches[variant] + 0
    }
}' "$raw_log" > "$summary_log"

cat "$summary_log"

if grep -q 'comparison_status=fail' "$raw_log"; then
    echo "Protected/baseline comparison contains failed cases." >&2
    exit 1
fi
