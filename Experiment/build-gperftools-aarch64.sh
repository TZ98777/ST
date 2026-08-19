#!/usr/bin/env bash
set -euo pipefail

lab_root=/home/brave/stickytags-lab
repo_source="$lab_root/src/stickytags/gperftools"
work_source="$lab_root/build/gperftools-aarch64-src"
install_dir="$lab_root/build/gperftools-aarch64-install"
llvm_build="$lab_root/build/llvm-rel-gcc13"
log_file="$lab_root/logs/stage5-gperftools-build.log"

if [[ ! -d "$work_source" ]]; then
    cp -a "$repo_source" "$work_source"
fi

cd "$work_source"

{
    if [[ ! -x configure ]]; then
        ./autogen.sh
    fi

    if [[ ! -f config.status ]]; then
        ./configure \
            --build="$(gcc -dumpmachine)" \
            --host=aarch64-linux-gnu \
            --prefix="$install_dir" \
            --enable-emergency-malloc \
            CC="$llvm_build/bin/clang --target=aarch64-linux-gnu --gcc-toolchain=/usr" \
            CXX="$llvm_build/bin/clang++ --target=aarch64-linux-gnu --gcc-toolchain=/usr" \
            AR=/usr/bin/aarch64-linux-gnu-ar \
            RANLIB=/usr/bin/aarch64-linux-gnu-ranlib \
            STRIP=/usr/bin/aarch64-linux-gnu-strip \
            CFLAGS='-O2 -march=armv8.5-a+memtag' \
            CXXFLAGS='-O2 -march=armv8.5-a+memtag' \
            LDFLAGS='-fuse-ld=lld -march=armv8.5-a+memtag'
    fi

    make -j2
    make install
} 2>&1 | tee "$log_file"
