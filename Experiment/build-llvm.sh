#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lab-env.sh"
LAB=$STICKYTAGS_LAB_ROOT
BUILD="$LAB/build/llvm-rel-gcc13"
LOG="$LAB/logs/stage4-llvm-build-gcc13.log"

cmake --build "$BUILD" --target clang lld -- -j2 2>&1 | tee "$LOG"

"$BUILD/bin/clang" --version
"$BUILD/bin/ld.lld" --version

echo "Built StickyTags LLVM/Clang successfully"
echo "Log: $LOG"
