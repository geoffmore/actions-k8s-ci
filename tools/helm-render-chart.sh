#!/bin/bash
# Renders a local Helm chart to stdout.
# Optionally renders from a specific git ref (for base-vs-PR comparisons).
# Usage: helm-render-chart [--ref <git-ref>] [--release-name <name>] [--lint] [--lint-config <path>] <chart-path>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/common.sh"

DO_LINT=false
KUBE_LINTER_CONFIG=""
GIT_REF=""
RELEASE_NAME=""

while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --ref)          GIT_REF="$2";             shift 2 ;;
    --release-name) RELEASE_NAME="$2";        shift 2 ;;
    --lint)         DO_LINT=true;             shift ;;
    --lint-config)  KUBE_LINTER_CONFIG="$2";  shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

CHART_PATH="${1:?Usage: helm-render-chart [--ref <git-ref>] <chart-path>}"
CHART_DIR="$(cd "$CHART_PATH" && pwd)"
REPO_ROOT="$(git -C "$CHART_DIR" rev-parse --show-toplevel)"
CHART_REL="${CHART_DIR#"$REPO_ROOT/"}"

: "${RELEASE_NAME:=$(basename "$CHART_DIR")}"

# Declare at script scope so the EXIT trap can reference them
rendered=""
tmpdir=""
trap '[[ -n "$rendered" ]] && rm -f "$rendered"; [[ -n "$tmpdir" ]] && rm -rf "$tmpdir"' EXIT

check_deps

rendered="$(mktemp)"

if [ -n "$GIT_REF" ]; then
  tmpdir="$(mktemp -d)"
  git -C "$REPO_ROOT" archive "$GIT_REF" -- "$CHART_REL" | tar -x -C "$tmpdir"
  helm template "$RELEASE_NAME" "$tmpdir/$CHART_REL" > "$rendered"
else
  helm template "$RELEASE_NAME" "$CHART_DIR" > "$rendered"
fi

cat "$rendered"

if "$DO_LINT"; then
  : "${KUBE_LINTER_CONFIG:=$REPO_ROOT/.kube-linter.yaml}"
  [ -f "$KUBE_LINTER_CONFIG" ] || KUBE_LINTER_CONFIG="${SCRIPT_DIR}/.kube-linter.yaml"
  kube-linter lint --config "$KUBE_LINTER_CONFIG" "$rendered"
fi
