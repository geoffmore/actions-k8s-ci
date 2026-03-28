#!/bin/bash
# Renders an ArgoCD Application manifest to stdout.
# Handles Helm (HTTP repo, OCI) and Kustomize source types.
# Usage: ./tools/argocd-render-application [--lint] [--lint-config <path>] <path/to/application.yaml>
set -euo pipefail

# Needed to source relative to local file path instead of caller path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/argocd.sh"

DO_LINT=false
KUBE_LINTER_CONFIG=""

while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --lint) DO_LINT=true; shift ;;
    --lint-config) KUBE_LINTER_CONFIG="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

setup_app_context "$1"

main() {
  check_deps

  rendered=$(mktemp)
  trap 'rm -f "$rendered"' EXIT

  local is_multi
  is_multi=$(yq '.spec | has("sources")' "$APP_FILE")

  if [ "$is_multi" = "true" ]; then
    handle_multi_source "${APP_FILE}" > "$rendered"
  else
    handle_single_source "${APP_FILE}" > "$rendered"
  fi

  cat "$rendered"

  if "$DO_LINT"; then
    : "${KUBE_LINTER_CONFIG:=$REPO_ROOT/.kube-linter.yaml}"
    # Fall back to bundled default if repo doesn't have its own config
    [ -f "$KUBE_LINTER_CONFIG" ] || KUBE_LINTER_CONFIG="${SCRIPT_DIR}/.kube-linter.yaml"
    kube-linter lint --config "$KUBE_LINTER_CONFIG" "$rendered"
  fi
}

main
