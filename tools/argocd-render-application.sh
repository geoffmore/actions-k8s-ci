#!/bin/bash
# Renders an ArgoCD Application manifest to stdout.
# Handles Helm (HTTP repo, OCI) and Kustomize source types.
# Usage: ./tools/argo-render-application <path/to/application.yaml>
set -euo pipefail

# Needed to source relative to local file path instead of caller path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/argocd.sh"

APP_FILE="$1"
APP_DIR="$(cd "$(dirname "$APP_FILE")" && pwd)"
REPO_ROOT="$(git -C "$APP_DIR" rev-parse --show-toplevel)"
CURRENT_REPO_URL="$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || echo "")"

render_kustomize() {
  local repo_url="$1" path="$2"

  if [[ "$repo_url" == *"$CURRENT_REPO_URL"* ]] || [[ "$repo_url" == *.git ]]; then
    if [ -f "$REPO_ROOT/$path/kustomization.yaml" ] || [ -f "$REPO_ROOT/$path/kustomization.yml" ]; then
      kustomize build "$REPO_ROOT/$path"
    else
      # Plain directory — output all YAML files
      find "$REPO_ROOT/$path" -name "*.yaml" -o -name "*.yml" | sort | xargs cat
    fi
  else
    echo "SKIP: Kustomize/plain source from external repo ($repo_url) is not supported." >&2
    exit 0
  fi
}

main() {
  check_deps

  local is_multi
  is_multi=$(yq '.spec | has("sources")' "$APP_FILE")

  if [ "$is_multi" = "true" ]; then
    handle_multi_source "${APP_FILE}"
  else
    handle_single_source "${APP_FILE}"
  fi
}

main
