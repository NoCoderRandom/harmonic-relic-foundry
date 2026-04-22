#!/usr/bin/env bash

set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly BUILD_DIR="$ROOT_DIR/build"
readonly BINARY_PATH="$BUILD_DIR/harmonic_relic_foundry"
readonly OUTPUT_DIR="$ROOT_DIR/docs/screenshots"
readonly FRAME_DELAY="${FRAME_DELAY:-40}"

mkdir -p "$OUTPUT_DIR"

if [[ ! -x "$BINARY_PATH" ]]; then
  "$ROOT_DIR/build.sh"
fi

run_capture() {
  local name="$1"
  shift

  local shot_dir
  local ppm_path

  shot_dir="$(mktemp -d "/tmp/hrf-gallery-${name}-XXXXXX")"

  timeout 20s \
    "$BINARY_PATH" \
    --capture-dir "$shot_dir" \
    --frames-before-capture "$FRAME_DELAY" \
    --auto-capture \
    --exit-after-capture \
    "$@"

  ppm_path="$(find "$shot_dir" -maxdepth 1 -name 'hrf_capture_*.ppm' | sort | head -n 1)"
  if [[ -z "$ppm_path" ]]; then
    printf '[FAIL] No capture produced for %s\n' "$name" >&2
    return 1
  fi

  ffmpeg -loglevel error -y -i "$ppm_path" "$OUTPUT_DIR/${name}.png"
  printf '[ OK ] %s -> %s\n' "$name" "$OUTPUT_DIR/${name}.png"
}

run_capture "gallery-default-shrine" \
  --seed 1847 \
  --camera 0.50 0.54 -1.15 0.00 0.00 55.0

run_capture "gallery-offset-cathedral" \
  --seed 1934 \
  --symmetry-offset 2 \
  --glyph-bias 0.16 \
  --pulse-scale 1.35 \
  --camera 0.43 0.58 -0.92 0.24 -0.05 46.0

run_capture "gallery-close-fracture-study" \
  --seed 2119 \
  --symmetry-offset -1 \
  --glyph-bias 0.12 \
  --pulse-scale 1.55 \
  --camera 0.61 0.47 -0.72 -0.30 0.12 40.0
