#!/usr/bin/env bash
set -euo pipefail

lab_root=/home/brave/stickytags-lab
ssh_key=/home/brave/.ssh/stickytags_vm_ed25519

for attempt in {1..60}; do
    if ssh \
        -i "$ssh_key" \
        -p 2222 \
        -o BatchMode=yes \
        -o ConnectTimeout=3 \
        -o StrictHostKeyChecking=no \
        brave@127.0.0.1 true 2>/dev/null; then
        echo "SSH_READY"
        exit 0
    fi
    echo "waiting_for_ssh_$attempt"
    sleep 5
done

echo "SSH did not become ready; latest console output follows" >&2
tail -n 50 "$lab_root/logs/qemu-mte-console.log" >&2
exit 1
