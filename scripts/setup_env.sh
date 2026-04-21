#!/usr/bin/env bash

set -euo pipefail

readonly PROJECT_NAME="Harmonic Relic Foundry"
readonly REQUIRED_PACKAGES=(
  gfortran
  gcc
  cmake
  build-essential
  mesa-utils
  libglfw3-dev
  libgl1-mesa-dev
  libglu1-mesa-dev
  xorg-dev
)
readonly REQUIRED_TOOLS=(
  gfortran
  gcc
  cmake
)

phase() {
  printf '\n[%s] %s\n' "PHASE" "$1"
}

ok() {
  printf '[ OK ] %s\n' "$1"
}

warn() {
  printf '[WARN] %s\n' "$1"
}

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

detect_platform() {
  local kernel
  kernel="$(uname -s 2>/dev/null || true)"
  [[ "$kernel" == "Linux" ]] || fail "Unsupported operating system: ${kernel:-unknown}. Linux or WSL2 is required."

  if grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; then
    if [[ -n "${WSL_INTEROP:-}" ]] || [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
      PLATFORM_KIND="wsl"
      if grep -qi 'wsl2' /proc/version 2>/dev/null || [[ -d /run/WSL ]]; then
        WSL_VERSION="2"
      else
        WSL_VERSION="unknown"
      fi
    else
      PLATFORM_KIND="linux"
      WSL_VERSION=""
    fi
  else
    PLATFORM_KIND="linux"
    WSL_VERSION=""
  fi
}

verify_display_support() {
  local has_display="false"

  if [[ -n "${DISPLAY:-}" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    has_display="true"
  fi

  if [[ "$PLATFORM_KIND" == "wsl" ]]; then
    [[ "${WSL_VERSION:-}" == "2" ]] || fail "WSL was detected, but WSL2 could not be confirmed. WSL2 is required."

    if [[ -d /mnt/wslg ]] || [[ -S /tmp/.X11-unix/X0 ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
      has_display="true"
    fi

    [[ "$has_display" == "true" ]] || fail "WSL2 detected, but GUI display support is missing. Ensure WSLg or an X server is configured before continuing."
    ok "WSL2 environment detected with GUI display support available."
    return
  fi

  [[ "$has_display" == "true" ]] || fail "No GUI display session detected. Set up X11 or Wayland support before continuing."
  ok "Linux GUI display support detected."
}

require_apt() {
  command_exists apt-get || fail "This setup script currently supports apt-based systems only."

  if [[ "${EUID}" -eq 0 ]]; then
    APT_PREFIX=()
  elif command_exists sudo; then
    APT_PREFIX=(sudo)
  else
    fail "sudo is required to install packages when not running as root."
  fi
}

install_packages() {
  local missing_packages=()
  local pkg

  for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
      ok "Package already installed: $pkg"
    else
      missing_packages+=("$pkg")
    fi
  done

  if (( ${#missing_packages[@]} == 0 )); then
    ok "All required apt packages are already installed."
    return
  fi

  printf '[INFO] Installing missing packages: %s\n' "${missing_packages[*]}"
  "${APT_PREFIX[@]}" apt-get update
  "${APT_PREFIX[@]}" apt-get install -y "${missing_packages[@]}"
  ok "Required apt packages installed."
}

verify_toolchain() {
  local tool

  for tool in "${REQUIRED_TOOLS[@]}"; do
    command_exists "$tool" || fail "Required tool not found after setup: $tool"
    ok "Tool available: $tool"
  done
}

report_gpu_status() {
  local nvidia_detected="false"

  if command_exists nvidia-smi; then
    ok "Optional NVIDIA tooling detected: nvidia-smi"
    nvidia_detected="true"
  fi

  if command_exists nvcc; then
    ok "Optional NVIDIA CUDA compiler detected: nvcc"
    nvidia_detected="true"
  fi

  if [[ "$nvidia_detected" == "false" ]]; then
    warn "Optional NVIDIA tooling not detected. GPU acceleration may be unavailable later, but this is not fatal."
  fi
}

main() {
  printf '== %s environment setup ==\n' "$PROJECT_NAME"

  phase "Detect operating environment"
  detect_platform
  if [[ "$PLATFORM_KIND" == "wsl" ]]; then
    ok "Environment verified: WSL${WSL_VERSION}"
  else
    ok "Environment verified: native Linux"
  fi

  phase "Verify GUI/OpenGL prerequisites"
  verify_display_support

  phase "Verify package manager access"
  require_apt
  ok "apt-based package management available."

  phase "Install required development packages"
  install_packages

  phase "Verify compiler and build tools"
  verify_toolchain

  phase "Check optional NVIDIA tooling"
  report_gpu_status

  phase "Setup complete"
  ok "Environment verification and dependency setup completed successfully."
}

PLATFORM_KIND=""
WSL_VERSION=""
APT_PREFIX=()

main "$@"
