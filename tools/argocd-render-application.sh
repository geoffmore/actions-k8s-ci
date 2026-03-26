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

render_helm() {
  local repo_url="$1" chart="$2" version="$3" release_name="$4"
  shift 4

  # Check for git chart source
  if [[ "$repo_url" == *.git ]] || [[ "$repo_url" == *"github.com/"* ]] || [[ "$repo_url" == *"gitlab.com/"* ]]; then
    if [ "$repo_url" = "$CURRENT_REPO_URL" ]; then
      helm template "$release_name" "$REPO_ROOT/$chart"
    else
      echo "SKIP: Git chart source from external repo ($repo_url) is not supported." >&2
      exit 0
    fi
    return
  fi

  local value_flags=()
  for f in "$@"; do
    if [[ "$f" == \$values/* ]]; then
      value_flags+=(-f "${f/\$values\//$REPO_ROOT/}")
    else
      value_flags+=(-f "$APP_DIR/$f")
    fi
  done

  if [[ "$repo_url" == oci://* ]]; then
    helm template "$release_name" "${repo_url}/${chart}" --version "$version" "${value_flags[@]+"${value_flags[@]}"}"
  else
    local repo_alias="render-tmp-$$"
    helm repo add "$repo_alias" "$repo_url" --force-update >/dev/null
    helm repo update "$repo_alias" >/dev/null
    helm template "$release_name" "${repo_alias}/${chart}" --version "$version" "${value_flags[@]+"${value_flags[@]}"}"
    helm repo remove "$repo_alias" >/dev/null
  fi
}

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
