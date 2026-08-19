#!/usr/bin/env bash
set -euo pipefail

lab_root=/home/brave/stickytags-lab
llvm_build="$lab_root/build/llvm-rel-gcc13"
tcmalloc_install="$lab_root/build/gperftools-aarch64-install"
artifact_dir="$lab_root/artifacts/aarch64"
source_file=/mnt/f/Paper/StickyTags/Experiment/tests/stickytags-level2.c
log_file="$lab_root/logs/stage8-level2-build.log"

mkdir -p "$artifact_dir/bin" "$artifact_dir/lib" "$lab_root/logs"

common_protected_flags=(
    --target=aarch64-linux-gnu
    --gcc-toolchain=/usr
    -march=armv8.5-a+memtag
    -fsanitize=safe-stack
    -O2
    -g
    -flto=full
    -fuse-ld=lld
    -fno-builtin-malloc
    -L"$tcmalloc_install/lib"
    -Wl,-rpath,/opt/stickytags/lib
    -Wl,--no-as-needed
    -ltcmalloc
    -lpthread
    -ldl
)

{
    echo "Building StickyTags level2 protected test"
    "$llvm_build/bin/clang" \
        "$source_file" \
        "${common_protected_flags[@]}" \
        -o "$artifact_dir/bin/stickytags-level2"

    echo "Building level2 unprotected baseline test"
    "$llvm_build/bin/clang" \
        --target=aarch64-linux-gnu \
        --gcc-toolchain=/usr \
        -march=armv8.5-a+memtag \
        -O0 \
        -g \
        "$source_file" \
        -o "$artifact_dir/bin/unprotected-level2"

    install -m 0755 \
        "$tcmalloc_install/lib/libtcmalloc.so.4.5.10" \
        "$artifact_dir/lib/libtcmalloc.so.4.5.10"
    ln -sfn libtcmalloc.so.4.5.10 "$artifact_dir/lib/libtcmalloc.so.4"
    ln -sfn libtcmalloc.so.4.5.10 "$artifact_dir/lib/libtcmalloc.so"

    file "$artifact_dir/bin/stickytags-level2"
    aarch64-linux-gnu-readelf -d "$artifact_dir/bin/stickytags-level2" \
        | grep -E 'NEEDED|RPATH|RUNPATH'
    echo "SafeStack symbol count:"
    aarch64-linux-gnu-nm "$artifact_dir/bin/stickytags-level2" \
        | grep -c '__safestack_init' || true
    echo "Baseline TCMalloc dependency count:"
    aarch64-linux-gnu-readelf -d "$artifact_dir/bin/unprotected-level2" \
        | grep -c 'libtcmalloc' || true
} 2>&1 | tee "$log_file"
