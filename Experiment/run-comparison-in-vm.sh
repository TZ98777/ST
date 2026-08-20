#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/lab-env.sh"
lab_root=$STICKYTAGS_LAB_ROOT
ssh_key=$STICKYTAGS_SSH_KEY
remote="$STICKYTAGS_VM_USER@$STICKYTAGS_VM_HOST"
guest_script="$script_dir/run-comparison-guest.sh"
artifact="$lab_root/artifacts/aarch64/bin/unprotected-functional"
raw_log="$lab_root/logs/stage7-comparison-results.csv"
summary_log="$lab_root/logs/stage7-comparison-summary.txt"
trials=${1:-20}
if [[ ! $trials =~ ^[1-9][0-9]*$ ]]; then
    echo "trials must be a positive integer: $trials" >&2
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

scp_options=(
    -i "$ssh_key"
    -P "$STICKYTAGS_VM_PORT"
    -o BatchMode=yes
    -o ConnectTimeout=60
    -o ServerAliveInterval=30
    -o StrictHostKeyChecking=no
)

scp "${scp_options[@]}" "$artifact" \
    "$remote":/tmp/unprotected-functional
ssh "${ssh_options[@]}" "$remote" \
    'sudo install -m 0755 /tmp/unprotected-functional /opt/stickytags/bin/unprotected-functional'

ssh "${ssh_options[@]}" "$remote" \
    "bash -s -- '$trials' '$STICKYTAGS_CASE_TIMEOUT'" \
    < "$guest_script" > "$raw_log"

{
    echo "variant,case,runs,mte_faults,detection_rate_percent"
    awk -F, '
    NR == 1 { next }
    {
        key=$1 "," $2
        runs[key]++
        if ($5 == 1) faults[key]++
        statuses[key "," $4]++
    }
    END {
        for (key in runs) {
            printf "%s,%d,%d,%.1f\n", key, runs[key], faults[key]+0,
                   100.0*(faults[key]+0)/runs[key]
        }
    }
' "$raw_log" | sort
} > "$summary_log"

cat "$summary_log"

if awk -F, 'NR > 1 && $10 != 1 { found = 1 } END { exit(found ? 0 : 1) }' "$raw_log"; then
    echo "Functional comparison contains cases that do not match the expected MTE behavior." >&2
    exit 1
fi
