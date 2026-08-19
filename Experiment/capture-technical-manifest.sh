#!/usr/bin/env bash
set -euo pipefail

lab_root=/home/brave/stickytags-lab
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo="$lab_root/src/stickytags"
artifact_dir="$lab_root/artifacts/aarch64"
output_dir="$script_dir"
manifest="$output_dir/manifests/technical-reproduction-manifest.txt"
archive_dir="$output_dir/artifacts"

mkdir -p "$output_dir/manifests" "$archive_dir"

{
    echo "=== capture time ==="
    date --iso-8601=seconds
    echo

    echo "=== source revisions ==="
    git -C "$repo" rev-parse HEAD
    git -C "$repo" submodule status --recursive
    printf 'working tree changes: '
    git -C "$repo" status --short | wc -l
    echo

    echo "=== host-side tools ==="
    "$lab_root/build/llvm-rel-gcc13/bin/clang" --version | head -n 2
    qemu-system-aarch64 --version | head -n 1
    cmake --version | head -n 1
    ninja --version
    echo

    echo "=== AArch64 artifacts ==="
    file "$artifact_dir/bin/stickytags-functional"
    file "$artifact_dir/bin/unprotected-functional"
    file "$artifact_dir/lib/libtcmalloc.so.4.5.10"
    sha256sum \
        "$artifact_dir/bin/stickytags-functional" \
        "$artifact_dir/bin/unprotected-functional" \
        "$artifact_dir/bin/repository-test" \
        "$artifact_dir/lib/libtcmalloc.so.4.5.10"
    echo

    echo "=== protected binary evidence ==="
    aarch64-linux-gnu-readelf -d "$artifact_dir/bin/stickytags-functional" \
        | grep -E 'NEEDED|RPATH|RUNPATH'
    aarch64-linux-gnu-nm "$artifact_dir/bin/stickytags-functional" \
        | grep '__safestack_init'
    echo

    echo "=== baseline binary evidence ==="
    aarch64-linux-gnu-readelf -d "$artifact_dir/bin/unprotected-functional" \
        | grep NEEDED
    printf 'SafeStack symbols: '
    aarch64-linux-gnu-nm "$artifact_dir/bin/unprotected-functional" \
        | grep -c '__safestack_init' || true
    printf 'TCMalloc dependencies: '
    aarch64-linux-gnu-readelf -d "$artifact_dir/bin/unprotected-functional" \
        | grep -c 'libtcmalloc' || true
    echo

    echo "=== running QEMU process ==="
    ps -eo pid,etime,%cpu,%mem,cmd | grep '[q]emu-system-aarch64'
} > "$manifest"

tar -C "$lab_root/artifacts" -czf \
    "$archive_dir/stickytags-aarch64-artifacts.tar.gz" aarch64

sha256sum "$archive_dir/stickytags-aarch64-artifacts.tar.gz" \
    > "$archive_dir/stickytags-aarch64-artifacts.tar.gz.sha256"

cat "$manifest"
