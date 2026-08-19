#!/usr/bin/env bash
set -euo pipefail

lab_root=/home/brave/stickytags-lab
source_dir="$lab_root/src/stickytags/llvm-project/compiler-rt"
llvm_build="$lab_root/build/llvm-rel-gcc13"
build_dir="$lab_root/build/compiler-rt-aarch64"
log_file="$lab_root/logs/stage5-compiler-rt-configure.log"

cmake -S "$source_dir" -B "$build_dir" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
    -DCMAKE_C_COMPILER="$llvm_build/bin/clang" \
    -DCMAKE_CXX_COMPILER="$llvm_build/bin/clang++" \
    -DCMAKE_ASM_COMPILER="$llvm_build/bin/clang" \
    -DCMAKE_C_COMPILER_TARGET=aarch64-linux-gnu \
    -DCMAKE_CXX_COMPILER_TARGET=aarch64-linux-gnu \
    -DCMAKE_ASM_COMPILER_TARGET=aarch64-linux-gnu \
    -DCMAKE_AR=/usr/bin/aarch64-linux-gnu-ar \
    -DCMAKE_RANLIB=/usr/bin/aarch64-linux-gnu-ranlib \
    -DCMAKE_C_FLAGS='--gcc-toolchain=/usr -march=armv8.5-a+memtag' \
    -DCMAKE_CXX_FLAGS='--gcc-toolchain=/usr -march=armv8.5-a+memtag' \
    -DCMAKE_ASM_FLAGS='--gcc-toolchain=/usr -march=armv8.5-a+memtag' \
    -DCMAKE_EXE_LINKER_FLAGS='--gcc-toolchain=/usr -fuse-ld=lld' \
    -DLLVM_CONFIG_PATH="$llvm_build/bin/llvm-config" \
    -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON \
    -DCOMPILER_RT_DEFAULT_TARGET_ARCH=aarch64 \
    -DCOMPILER_RT_BUILD_BUILTINS=OFF \
    -DCOMPILER_RT_BUILD_SANITIZERS=ON \
    -DCOMPILER_RT_BUILD_XRAY=OFF \
    -DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
    -DCOMPILER_RT_BUILD_PROFILE=OFF \
    -DCOMPILER_RT_BUILD_MEMPROF=OFF \
    -DCOMPILER_RT_BUILD_CTX_PROFILE=OFF \
    -DCOMPILER_RT_INCLUDE_TESTS=OFF \
    2>&1 | tee "$log_file"
