#!/usr/bin/env bash

set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BUILD_REQUIREMENTS_FILE="$ROOT_DIR/requirements-build.txt"
readonly RUNTIME_REQUIREMENTS_FILE="$ROOT_DIR/requirements-runtime.txt"

MODE="install"

usage() {
  cat <<'EOF'
Usage: ./install_requirements.sh [--install|--check|--print]

Options:
  --install   Install missing packages using apt-get (default)
  --check     Report missing packages without installing them
  --print     Print the package lists and exit
EOF
}

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

info() {
  printf '[INFO] %s\n' "$1"
}

ok() {
  printf '[ OK ] %s\n' "$1"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

read_requirements() {
  local file_path="$1"
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -n "$line" ]] && printf '%s\n' "$line"
  done < "$file_path"
}

print_requirements() {
  printf 'Build requirements (%s):\n' "$(basename "$BUILD_REQUIREMENTS_FILE")"
  read_requirements "$BUILD_REQUIREMENTS_FILE"
  printf '\nRuntime requirements (%s):\n' "$(basename "$RUNTIME_REQUIREMENTS_FILE")"
  read_requirements "$RUNTIME_REQUIREMENTS_FILE"
}

collect_missing_packages() {
  local package
  local -n output_ref="$1"
  shift

  output_ref=()

  for package in "$@"; do
    if dpkg -s "$package" >/dev/null 2>&1; then
      ok "Package already installed: $package"
    else
      output_ref+=("$package")
    fi
  done
}

main() {
  local arg
  local -a packages=()
  local -a missing_packages=()
  local -a apt_prefix=()

  for arg in "$@"; do
    case "$arg" in
      --install)
        MODE="install"
        ;;
      --check)
        MODE="check"
        ;;
      --print)
        MODE="print"
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        usage
        fail "Unknown argument: $arg"
        ;;
    esac
  done

  [[ -f "$BUILD_REQUIREMENTS_FILE" ]] || fail "Missing $BUILD_REQUIREMENTS_FILE"
  [[ -f "$RUNTIME_REQUIREMENTS_FILE" ]] || fail "Missing $RUNTIME_REQUIREMENTS_FILE"

  if [[ "$MODE" == "print" ]]; then
    print_requirements
    exit 0
  fi

  command_exists apt-get || fail "This installer currently supports apt-based systems only."

  while IFS= read -r package; do
    packages+=("$package")
  done < <(read_requirements "$BUILD_REQUIREMENTS_FILE")

  while IFS= read -r package; do
    packages+=("$package")
  done < <(read_requirements "$RUNTIME_REQUIREMENTS_FILE")

  collect_missing_packages missing_packages "${packages[@]}"

  if (( ${#missing_packages[@]} == 0 )); then
    ok "All required packages are already installed."
    exit 0
  fi

  if [[ "$MODE" == "check" ]]; then
    info "Missing packages:"
    printf '  %s\n' "${missing_packages[@]}"
    exit 1
  fi

  if [[ "${EUID}" -eq 0 ]]; then
    apt_prefix=()
  elif command_exists sudo; then
    apt_prefix=(sudo)
  else
    fail "sudo is required to install packages when not running as root."
  fi

  info "Installing missing packages:"
  printf '  %s\n' "${missing_packages[@]}"
  "${apt_prefix[@]}" apt-get update
  "${apt_prefix[@]}" apt-get install -y "${missing_packages[@]}"
  ok "Dependency installation completed."
}

main "$@"
