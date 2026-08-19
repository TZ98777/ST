#!/usr/bin/env bash

set -euo pipefail

LAB_ROOT="$HOME/stickytags-lab"
SOURCE_ROOT="$LAB_ROOT/src"
LOG_ROOT="$LAB_ROOT/logs"
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
EXPERIMENT_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
REPO_ROOT="$SOURCE_ROOT/stickytags"
PINNED_COMMIT="db3ba2616ce0935fba6352192a43010ba9d3172a"

mkdir -p "$SOURCE_ROOT" "$LOG_ROOT"
mkdir -p "$EXPERIMENT_ROOT/logs" "$EXPERIMENT_ROOT/manifests"

for file in stage2-tool-versions.txt packages-after-stage2.txt; do
  if [[ -f "$LOG_ROOT/$file" ]]; then
    cp -f "$LOG_ROOT/$file" "$EXPERIMENT_ROOT/manifests/"
  fi
done

if [[ -f "$LOG_ROOT/stage2-apt-install.log" ]]; then
  cp -f "$LOG_ROOT/stage2-apt-install.log" "$EXPERIMENT_ROOT/logs/"
fi

if [[ -e "$REPO_ROOT" && ! -d "$REPO_ROOT/.git" ]]; then
  echo "ERROR: $REPO_ROOT exists but is not a Git working tree." >&2
  exit 1
fi

if [[ ! -d "$REPO_ROOT/.git" ]]; then
  git clone --recurse-submodules https://github.com/vusec/stickytags.git "$REPO_ROOT" \
    2>&1 | tee "$LOG_ROOT/stage3-clone.log"
fi

cd "$REPO_ROOT"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: repository contains local changes; refusing to switch commits." >&2
  git status --short
  exit 1
fi

git checkout "$PINNED_COMMIT"
git submodule update --init --recursive \
  2>&1 | tee "$LOG_ROOT/stage3-submodules.log"

{
  echo "=== DATE ==="
  date -Iseconds
  echo "=== MAIN COMMIT ==="
  git rev-parse HEAD
  echo "=== SUBMODULES ==="
  git submodule status --recursive
  echo "=== STATUS ==="
  git status --short --branch
  echo "=== SIZE ==="
  du -sh .
  echo "=== SPECTRE-MTE SAMPLE ==="
  find spectre-mte -maxdepth 2 -type f | sort | head -n 20
} 2>&1 | tee "$LOG_ROOT/stage3-git-state.txt"

cp -f "$LOG_ROOT/stage3-clone.log" "$EXPERIMENT_ROOT/logs/" 2>/dev/null || true
cp -f "$LOG_ROOT/stage3-submodules.log" "$EXPERIMENT_ROOT/logs/"
cp -f "$LOG_ROOT/stage3-git-state.txt" "$EXPERIMENT_ROOT/manifests/"

echo "Stage 3 completed successfully."
