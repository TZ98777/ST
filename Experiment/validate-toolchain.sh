#!/usr/bin/env bash
set -euo pipefail

lab_root=/home/brave/stickytags-lab
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
build_dir="$lab_root/build/llvm-rel-gcc13"
source_file="$script_dir/tests/toolchain-smoke.c"
log_file=/home/brave/stickytags-lab/logs/stage4-toolchain-validation.txt
validation_dir="$lab_root/build/toolchain-validation"

mkdir -p "$validation_dir"

{
    echo "=== clang version ==="
    "$build_dir/bin/clang" --version

    echo "=== lld version ==="
    "$build_dir/bin/ld.lld" --version

    echo "=== LLVM IR ==="
    "$build_dir/bin/clang" \
        --target=aarch64-linux-gnu \
        -S -emit-llvm \
        "$source_file" \
        -o "$validation_dir/toolchain-smoke.ll"
    grep -E 'target triple|define.*main' "$validation_dir/toolchain-smoke.ll"

    echo "=== AArch64 object ==="
    "$build_dir/bin/clang" \
        --target=aarch64-linux-gnu \
        --gcc-toolchain=/usr \
        -march=armv8.5-a+memtag \
        -c "$source_file" \
        -o "$validation_dir/toolchain-smoke.o"
    file "$validation_dir/toolchain-smoke.o"
    aarch64-linux-gnu-readelf -h "$validation_dir/toolchain-smoke.o" \
        | grep -E 'Class:|Machine:'

    echo "=== SafeStack transform ==="
    "$build_dir/bin/clang" \
        --target=aarch64-linux-gnu \
        --gcc-toolchain=/usr \
        -march=armv8.5-a+memtag \
        -fsanitize=safe-stack \
        -O2 -S -emit-llvm \
        "$source_file" \
        -o "$validation_dir/toolchain-safestack.ll"
    grep -E 'safestack|define.*main' "$validation_dir/toolchain-safestack.ll" | head

    echo "=== SafeStack full-LTO executable ==="
    "$build_dir/bin/clang" \
        --target=aarch64-linux-gnu \
        --gcc-toolchain=/usr \
        -fuse-ld=lld \
        -march=armv8.5-a+memtag \
        -fsanitize=safe-stack \
        -O2 -flto=full \
        "$source_file" \
        -o "$validation_dir/toolchain-smoke-safestack-aarch64"
    file "$validation_dir/toolchain-smoke-safestack-aarch64"
    aarch64-linux-gnu-nm "$validation_dir/toolchain-smoke-safestack-aarch64" \
        | grep '__safestack_init'
} 2>&1 | tee "$log_file"
