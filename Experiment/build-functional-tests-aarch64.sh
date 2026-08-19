#!/usr/bin/env bash
set -euo pipefail

lab_root=/home/brave/stickytags-lab
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
llvm_build="$lab_root/build/llvm-rel-gcc13"
tcmalloc_install="$lab_root/build/gperftools-aarch64-install"
artifact_dir="$lab_root/artifacts/aarch64"
source_dir="$script_dir/tests"
log_file="$lab_root/logs/stage6-functional-test-build.log"

mkdir -p "$artifact_dir/bin" "$artifact_dir/lib"

common_flags=(
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
    "$llvm_build/bin/clang" \
        "$source_dir/stickytags-functional.c" \
        "${common_flags[@]}" \
        -o "$artifact_dir/bin/stickytags-functional"

    "$llvm_build/bin/clang" \
        "$lab_root/src/stickytags/test/test.c" \
        "${common_flags[@]}" \
        -o "$artifact_dir/bin/repository-test"

    install -m 0755 \
        "$tcmalloc_install/lib/libtcmalloc.so.4.5.10" \
        "$artifact_dir/lib/libtcmalloc.so.4.5.10"
    ln -sfn libtcmalloc.so.4.5.10 "$artifact_dir/lib/libtcmalloc.so.4"
    ln -sfn libtcmalloc.so.4.5.10 "$artifact_dir/lib/libtcmalloc.so"

    file "$artifact_dir/bin/stickytags-functional"
    aarch64-linux-gnu-readelf -d "$artifact_dir/bin/stickytags-functional" \
        | grep -E 'NEEDED|RPATH|RUNPATH'
    aarch64-linux-gnu-nm "$artifact_dir/bin/stickytags-functional" \
        | grep '__safestack_init'
} 2>&1 | tee "$log_file"
