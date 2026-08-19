#!/usr/bin/env bash
set -euo pipefail

lab_root=/home/brave/stickytags-lab
artifact_dir="$lab_root/artifacts/aarch64"
ssh_key=/home/brave/.ssh/stickytags_vm_ed25519
ssh_args=(
    -i "$ssh_key"
    -p 2222
    -o BatchMode=yes
    -o StrictHostKeyChecking=no
)

tar -C "$artifact_dir" -czf - . \
    | ssh "${ssh_args[@]}" brave@127.0.0.1 \
        'sudo mkdir -p /opt/stickytags && sudo tar -xzf - -C /opt/stickytags'

ssh "${ssh_args[@]}" brave@127.0.0.1 \
    'find /opt/stickytags -maxdepth 2 -type f -o -type l | sort; ldd /opt/stickytags/bin/stickytags-functional'
