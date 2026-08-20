#!/usr/bin/env bash

# Shared host-side defaults. Override these variables in the shell before
# running a script; no machine-specific values need to be committed.
STICKYTAGS_LAB_ROOT=${STICKYTAGS_LAB_ROOT:-"$HOME/stickytags-lab"}
STICKYTAGS_SSH_KEY=${STICKYTAGS_SSH_KEY:-"$HOME/.ssh/stickytags_vm_ed25519"}
STICKYTAGS_VM_HOST=${STICKYTAGS_VM_HOST:-127.0.0.1}
STICKYTAGS_VM_PORT=${STICKYTAGS_VM_PORT:-2222}
STICKYTAGS_VM_USER=${STICKYTAGS_VM_USER:-brave}
STICKYTAGS_VM_WAIT_ATTEMPTS=${STICKYTAGS_VM_WAIT_ATTEMPTS:-180}
STICKYTAGS_VM_WAIT_INTERVAL=${STICKYTAGS_VM_WAIT_INTERVAL:-5}
STICKYTAGS_CASE_TIMEOUT=${STICKYTAGS_CASE_TIMEOUT:-120}

if [[ ! $STICKYTAGS_VM_PORT =~ ^[1-9][0-9]*$ ]] ||
   ((STICKYTAGS_VM_PORT > 65535)); then
    echo "STICKYTAGS_VM_PORT must be between 1 and 65535." >&2
    return 64 2>/dev/null || exit 64
fi

for value_name in STICKYTAGS_VM_WAIT_ATTEMPTS STICKYTAGS_VM_WAIT_INTERVAL \
                  STICKYTAGS_CASE_TIMEOUT; do
    value=${!value_name}
    if [[ ! $value =~ ^[1-9][0-9]*$ ]]; then
        echo "$value_name must be a positive integer." >&2
        return 64 2>/dev/null || exit 64
    fi
done
