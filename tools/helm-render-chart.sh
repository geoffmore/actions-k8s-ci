#!/bin/bash
# Renders a local Helm chart to stdout.
# Usage: helm-render-chart [--values <file>]... [--release-name <name>] [--lint] [--lint-config <path>] <chart-path>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/common.sh"

DO_LINT=false
KUBE_LINTER_CONFIG=""
RELEASE_NAME=""
VALUE_FILES=()

while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --values)       VALUE_FILES+=("$2");      shift 2 ;;
    --release-name) RELEASE_NAME="$2";        shift 2 ;;
    --lint)         DO_LINT=true;             shift ;;
    --lint-config)  KUBE_LINTER_CONFIG="$2";  shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

CHART_PATH="${1:?Usage: helm-render-chart [--values <file>]... <chart-path>}"
CHART_DIR="$(cd "$CHART_PATH" && pwd)"
REPO_ROOT="$(git -C "$CHART_DIR" rev-parse --show-toplevel)"

: "${RELEASE_NAME:=$(basename "$CHART_DIR")}"

rendered=""
trap '[[ -n "$rendered" ]] && rm -f "$rendered"' EXIT

check_deps

# Resolve --values paths relative to the caller's working directory
value_flags=()
for f in "${VALUE_FILES[@]+"${VALUE_FILES[@]}"}"; do
  value_flags+=(-f "$(cd "$(dirname "$f")" && pwd)/$(basename "$f")")
done

rendered="$(mktemp)"
helm template "$RELEASE_NAME" "$CHART_DIR" "${value_flags[@]+"${value_flags[@]}"}" > "$rendered"

cat "$rendered"

if "$DO_LINT"; then
  : "${KUBE_LINTER_CONFIG:=$REPO_ROOT/.kube-linter.yaml}"
  [ -f "$KUBE_LINTER_CONFIG" ] || KUBE_LINTER_CONFIG="${SCRIPT_DIR}/.kube-linter.yaml"
  kube-linter lint --config "$KUBE_LINTER_CONFIG" "$rendered"
fi
