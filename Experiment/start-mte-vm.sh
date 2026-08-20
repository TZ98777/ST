#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lab-env.sh"
LAB=$STICKYTAGS_LAB_ROOT
VM_DIR="$LAB/vm"
LOG_DIR="$LAB/logs"
PID_FILE="$VM_DIR/qemu-mte.pid"
CONSOLE_LOG="$LOG_DIR/qemu-mte-console.log"

mkdir -p "$LOG_DIR"

if [[ -f "$PID_FILE" ]] && kill -0 "$(<"$PID_FILE")" 2>/dev/null; then
  echo "QEMU is already running with PID $(<"$PID_FILE")"
  exit 0
fi

: > "$CONSOLE_LOG"

qemu-system-aarch64 \
  -name stickytags-arm64-mte \
  -machine virt,mte=on \
  -cpu max \
  -accel tcg,thread=multi \
  -smp 2 \
  -m 2048 \
  -kernel "$VM_DIR/boot/Image-6.8.0-137-generic" \
  -initrd "$VM_DIR/boot/initrd.img-6.8.0-137-generic" \
  -append "root=/dev/vda1 rw rootwait console=ttyAMA0 earlycon=pl011,0x09000000 fstab=no apparmor=0 systemd.mask=apparmor.service systemd.mask=multipathd.service systemd.show_status=yes" \
  -drive if=none,file="$VM_DIR/images/stickytags-arm64-overlay.qcow2",format=qcow2,id=osdisk \
  -device virtio-blk-pci,drive=osdisk \
  -drive if=none,file="$VM_DIR/cloud-init/seed.img",format=raw,readonly=on,id=seed \
  -device virtio-blk-pci,drive=seed \
  -netdev "user,id=net0,hostfwd=tcp:${STICKYTAGS_VM_HOST}:${STICKYTAGS_VM_PORT}-:22" \
  -device virtio-net-pci,netdev=net0 \
  -device virtio-rng-pci \
  -display none \
  -serial "file:$CONSOLE_LOG" \
  -monitor none \
  -daemonize \
  -pidfile "$PID_FILE"

echo "Started QEMU PID $(<"$PID_FILE")"
echo "Console log: $CONSOLE_LOG"
