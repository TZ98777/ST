#!/usr/bin/env bash
set -euo pipefail

lab_root=/home/brave/stickytags-lab
ssh_key=/home/brave/.ssh/stickytags_vm_ed25519
pid_file="$lab_root/vm/qemu-mte.pid"

if [[ ! -f $pid_file ]] || ! kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    echo "QEMU_ALREADY_STOPPED"
    exit 0
fi

ssh \
    -i "$ssh_key" \
    -p 2222 \
    -o BatchMode=yes \
    -o ConnectTimeout=30 \
    -o StrictHostKeyChecking=no \
    brave@127.0.0.1 \
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
