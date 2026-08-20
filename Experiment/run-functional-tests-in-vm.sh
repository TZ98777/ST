#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/lab-env.sh"
lab_root=$STICKYTAGS_LAB_ROOT
ssh_key=$STICKYTAGS_SSH_KEY
remote="$STICKYTAGS_VM_USER@$STICKYTAGS_VM_HOST"
guest_script="$script_dir/run-functional-tests-guest.sh"
log_file="$lab_root/logs/stage6-functional-test-results.txt"

ssh \
    -i "$ssh_key" \
    -p "$STICKYTAGS_VM_PORT" \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=no \
    "$remote" \
    'bash -s' \
    < "$guest_script" \
    2>&1 | tee "$log_file"
