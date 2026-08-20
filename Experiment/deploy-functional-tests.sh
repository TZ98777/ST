#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/lab-env.sh"
lab_root=$STICKYTAGS_LAB_ROOT
artifact_dir="$lab_root/artifacts/aarch64"
ssh_key=$STICKYTAGS_SSH_KEY
remote="$STICKYTAGS_VM_USER@$STICKYTAGS_VM_HOST"
ssh_args=(
    -i "$ssh_key"
    -p "$STICKYTAGS_VM_PORT"
    -o BatchMode=yes
    -o StrictHostKeyChecking=no
)

tar -C "$artifact_dir" -czf - . \
    | ssh "${ssh_args[@]}" "$remote" \
        'sudo mkdir -p /opt/stickytags && sudo tar -xzf - -C /opt/stickytags'

ssh "${ssh_args[@]}" "$remote" \
    'find /opt/stickytags -maxdepth 2 -type f -o -type l | sort; ldd /opt/stickytags/bin/stickytags-functional'
