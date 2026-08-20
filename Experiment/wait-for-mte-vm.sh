#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/lab-env.sh"
lab_root=$STICKYTAGS_LAB_ROOT
ssh_key=$STICKYTAGS_SSH_KEY
remote="$STICKYTAGS_VM_USER@$STICKYTAGS_VM_HOST"

for ((attempt = 1; attempt <= STICKYTAGS_VM_WAIT_ATTEMPTS; ++attempt)); do
    if ssh \
        -i "$ssh_key" \
        -p "$STICKYTAGS_VM_PORT" \
        -o BatchMode=yes \
        -o ConnectTimeout=3 \
        -o StrictHostKeyChecking=no \
        "$remote" true 2>/dev/null; then
        echo "SSH_READY"
        exit 0
    fi
    echo "waiting_for_ssh_$attempt"
    sleep "$STICKYTAGS_VM_WAIT_INTERVAL"
done

echo "SSH did not become ready; latest console output follows" >&2
tail -n 50 "$lab_root/logs/qemu-mte-console.log" >&2
exit 1
