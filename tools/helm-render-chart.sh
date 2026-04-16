#!/bin/bash
# Renders a local Helm chart to stdout.
# Usage: helm-render-chart [--extra-values <file>]... [--release-name <name>] [--lint] [--lint-config <path>] <chart-path>
#
# --extra-values <file>  Additional values file, relative to the chart root or absolute.
#                        Applied on top of the chart's values.yaml. May be specified
#                        multiple times. Files are applied in order.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/common.sh"

DO_LINT=false
KUBE_LINTER_CONFIG=""
RELEASE_NAME=""
EXTRA_VALUE_FILES=()

while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --extra-values) EXTRA_VALUE_FILES+=("$2"); shift 2 ;;
    --release-name) RELEASE_NAME="$2";         shift 2 ;;
    --lint)         DO_LINT=true;              shift ;;
    --lint-config)  KUBE_LINTER_CONFIG="$2";   shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

CHART_PATH="${1:?Usage: helm-render-chart [--extra-values <file>]... <chart-path>}"
CHART_DIR="$(cd "$CHART_PATH" && pwd)"
REPO_ROOT="$(git -C "$CHART_DIR" rev-parse --show-toplevel)"

: "${RELEASE_NAME:=$(basename "$CHART_DIR")}"

rendered=""
trap '[[ -n "$rendered" ]] && rm -f "$rendered"' EXIT

check_deps

# Resolve --extra-values paths relative to the chart root (unless absolute).
# Missing files are silently skipped so the same extra-values list can be
# passed to all charts in a repo without requiring every chart to have them.
value_flags=()
for f in "${EXTRA_VALUE_FILES[@]+"${EXTRA_VALUE_FILES[@]}"}"; do
  if [[ "$f" == /* ]]; then
    [ -f "$f" ] && value_flags+=(-f "$f")
  else
    [ -f "$CHART_DIR/$f" ] && value_flags+=(-f "$CHART_DIR/$f")
  fi
done

rendered="$(mktemp)"
helm template "$RELEASE_NAME" "$CHART_DIR" \
  "${value_flags[@]+"${value_flags[@]}"}" \
  > "$rendered"

cat "$rendered"

if "$DO_LINT"; then
  : "${KUBE_LINTER_CONFIG:=$REPO_ROOT/.kube-linter.yaml}"
  [ -f "$KUBE_LINTER_CONFIG" ] || KUBE_LINTER_CONFIG="${SCRIPT_DIR}/.kube-linter.yaml"
  kube-linter lint --config "$KUBE_LINTER_CONFIG" "$rendered"
fi
