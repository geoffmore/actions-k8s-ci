#!/bin/bash
# Renders an ArgoCD Application manifest to stdout.
# Handles Helm (HTTP repo, OCI) and Kustomize source types.
# Usage: ./tools/argo-render-application <path/to/application.yaml>
set -euo pipefail

# Needed to source relative to local file path instead of caller path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/argocd.sh"

setup_app_context "$1"

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
