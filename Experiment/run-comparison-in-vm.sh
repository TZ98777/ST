#!/usr/bin/env bash
set -euo pipefail

lab_root=/home/brave/stickytags-lab
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ssh_key=/home/brave/.ssh/stickytags_vm_ed25519
guest_script="$script_dir/run-comparison-guest.sh"
artifact="$lab_root/artifacts/aarch64/bin/unprotected-functional"
raw_log="$lab_root/logs/stage7-comparison-results.csv"
summary_log="$lab_root/logs/stage7-comparison-summary.txt"
trials=${1:-20}

ssh_options=(
    -i "$ssh_key"
    -p 2222
    -o BatchMode=yes
    -o ConnectTimeout=60
    -o ServerAliveInterval=30
    -o StrictHostKeyChecking=no
)

scp_options=(
    -i "$ssh_key"
    -P 2222
    -o BatchMode=yes
    -o ConnectTimeout=60
    -o ServerAliveInterval=30
    -o StrictHostKeyChecking=no
)

scp "${scp_options[@]}" "$artifact" \
    brave@127.0.0.1:/tmp/unprotected-functional
ssh "${ssh_options[@]}" brave@127.0.0.1 \
    'sudo install -m 0755 /tmp/unprotected-functional /opt/stickytags/bin/unprotected-functional'

ssh "${ssh_options[@]}" brave@127.0.0.1 \
    "bash -s -- '$trials'" < "$guest_script" > "$raw_log"

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
