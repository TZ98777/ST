#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/lab-env.sh"
lab_root=$STICKYTAGS_LAB_ROOT
raw_log="$lab_root/logs/stage7-comparison-results.csv"
summary_log="$lab_root/logs/stage7-comparison-summary.txt"

{
    echo "variant,case,runs,mte_faults,detection_rate_percent"
    awk -F, '
        NR == 1 { next }
        {
            key=$1 "," $2
            runs[key]++
            if ($5 == 1) faults[key]++
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
