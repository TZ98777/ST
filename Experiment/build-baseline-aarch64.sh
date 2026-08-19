#!/usr/bin/env bash
set -euo pipefail

lab_root=/home/brave/stickytags-lab
llvm_build="$lab_root/build/llvm-rel-gcc13"
artifact_dir="$lab_root/artifacts/aarch64"
source_file=/mnt/f/Paper/StickyTags/Experiment/tests/stickytags-functional.c
log_file="$lab_root/logs/stage7-baseline-build.log"

mkdir -p "$artifact_dir/bin"

{
    echo "Building the same test without SafeStack and StickyTags TCMalloc"
    "$llvm_build/bin/clang" \
        --target=aarch64-linux-gnu \
        --gcc-toolchain=/usr \
        -march=armv8.5-a+memtag \
        -O0 \
        -g \
        "$source_file" \
        -o "$artifact_dir/bin/unprotected-functional"

    file "$artifact_dir/bin/unprotected-functional"
    echo "Dynamic dependencies:"
    aarch64-linux-gnu-readelf -d "$artifact_dir/bin/unprotected-functional" \
        | grep NEEDED
    echo "SafeStack symbol count (expected 0):"
    aarch64-linux-gnu-nm "$artifact_dir/bin/unprotected-functional" \
        | grep -c '__safestack_init' || true
    echo "TCMalloc dependency count (expected 0):"
    aarch64-linux-gnu-readelf -d "$artifact_dir/bin/unprotected-functional" \
        | grep -c 'libtcmalloc' || true
} 2>&1 | tee "$log_file"
