#!/usr/bin/env bash
set -euo pipefail

lab_root=/home/brave/stickytags-lab
ssh_key=/home/brave/.ssh/stickytags_vm_ed25519
guest_script=/mnt/f/Paper/StickyTags/Experiment/run-functional-tests-guest.sh
log_file="$lab_root/logs/stage6-functional-test-results.txt"

ssh \
    -i "$ssh_key" \
    -p 2222 \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=no \
    brave@127.0.0.1 \
    'bash -s' \
    < "$guest_script" \
    2>&1 | tee "$log_file"
