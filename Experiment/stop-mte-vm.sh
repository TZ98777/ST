#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/lab-env.sh"
lab_root=$STICKYTAGS_LAB_ROOT
ssh_key=$STICKYTAGS_SSH_KEY
remote="$STICKYTAGS_VM_USER@$STICKYTAGS_VM_HOST"
pid_file="$lab_root/vm/qemu-mte.pid"

if [[ ! -f $pid_file ]] || ! kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    echo "QEMU_ALREADY_STOPPED"
    exit 0
fi

ssh \
    -i "$ssh_key" \
    -p "$STICKYTAGS_VM_PORT" \
    -o BatchMode=yes \
    -o ConnectTimeout=30 \
    -o StrictHostKeyChecking=no \
    "$remote" \
    'sudo poweroff' || true

# QEMU TCG may need longer than native hardware for systemd's final shutdown jobs.
for _ in $(seq 1 120); do
    if ! kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        echo "QEMU_STOPPED"
        exit 0
    fi
    sleep 1
done

echo "QEMU_STILL_RUNNING"
exit 1
