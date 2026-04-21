#!/usr/bin/env bash

set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BUILD_DIR="$ROOT_DIR/build"
readonly BINARY_PATH="$BUILD_DIR/harmonic_relic_foundry"

if [[ ! -x "$BINARY_PATH" ]]; then
  printf '[INFO] No built binary found. Running ./build.sh first.\n'
  "$ROOT_DIR/build.sh"
fi

cd "$ROOT_DIR"
exec "$BINARY_PATH" "$@"
