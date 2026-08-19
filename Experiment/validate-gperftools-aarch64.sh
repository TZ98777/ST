#!/usr/bin/env bash
set -euo pipefail

lab_root=/home/brave/stickytags-lab
install_dir="$lab_root/build/gperftools-aarch64-install"
library="$install_dir/lib/libtcmalloc.so.4.5.10"
log_file="$lab_root/logs/stage5-gperftools-validation.txt"
validation_dir="$lab_root/build/gperftools-validation"
symbols_file="$validation_dir/libtcmalloc-symbols.txt"
disassembly_file="$validation_dir/libtcmalloc-disassembly.txt"

mkdir -p "$validation_dir"
aarch64-linux-gnu-nm -D "$library" > "$symbols_file"
aarch64-linux-gnu-objdump -d "$library" > "$disassembly_file"

{
    echo "=== installed libraries ==="
    ls -lh "$install_dir"/lib/libtcmalloc*

    echo "=== ELF architecture ==="
    file "$library"
    aarch64-linux-gnu-readelf -h "$library" | grep -E 'Class:|Machine:'

    echo "=== allocator symbols ==="
    grep -m 30 -E 'mte|tag|malloc' "$symbols_file"

    echo "=== MTE instructions ==="
    grep -m 20 -E '\b(irg|stg|st2g|stzg|ldg|addg|subg)\b' \
        "$disassembly_file"

    echo "=== repository status ==="
    git -C "$lab_root/src/stickytags" status --short
} 2>&1 | tee "$log_file"
