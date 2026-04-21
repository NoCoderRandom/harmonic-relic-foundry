#!/usr/bin/env bash

set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BUILD_DIR="$ROOT_DIR/build"

if command -v nproc >/dev/null 2>&1; then
  JOB_COUNT="${JOBS:-$(nproc)}"
else
  JOB_COUNT="${JOBS:-4}"
fi

printf '[INFO] Configuring project in %s\n' "$BUILD_DIR"
cmake -S "$ROOT_DIR" -B "$BUILD_DIR"

printf '[INFO] Building with %s parallel jobs\n' "$JOB_COUNT"
cmake --build "$BUILD_DIR" -j"$JOB_COUNT"

printf '[ OK ] Build finished: %s/harmonic_relic_foundry\n' "$BUILD_DIR"
