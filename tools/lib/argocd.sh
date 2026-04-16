# shellcheck shell=bash
# Prevent direct execution
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { echo "this lib must be sourced, not executed" >&2; exit 1; }

# Needed to source relative to local file path instead of caller path
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/common.sh"

setup_app_context() {
  APP_FILE="$1"
  APP_DIR="$(cd "$(dirname "$APP_FILE")" && pwd)"
  REPO_ROOT="$(git -C "$APP_DIR" rev-parse --show-toplevel)"
  CURRENT_REPO_URL="$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || echo "")"
}

render_kustomize() {
  local repo_url="$1" path="$2"
  local norm_repo="${repo_url%.git}"
  local norm_current="${CURRENT_REPO_URL%.git}"

  if [[ "$norm_repo" == "$norm_current" ]]; then
    if [ -f "$REPO_ROOT/$path/kustomization.yaml" ] || [ -f "$REPO_ROOT/$path/kustomization.yml" ]; then
      kustomize build "$REPO_ROOT/$path"
    else
      # Plain directory — output all YAML files for the caller to handle
      find "$REPO_ROOT/$path" -name "*.yaml" -o -name "*.yml" | sort | xargs cat
    fi
  else
    echo "SKIP: Kustomize/plain source from external repo ($repo_url) is not supported." >&2
    exit 0
  fi
}

render_helm() {
  local repo_url="$1" chart="$2" version="$3" release_name="$4"
  shift 4

  # Check for git chart source
  if [[ "$repo_url" == *.git ]] || [[ "$repo_url" == *"github.com/"* ]] || [[ "$repo_url" == *"gitlab.com/"* ]]; then
    if [[ "${repo_url%.git}" == "${CURRENT_REPO_URL%.git}" ]]; then
      # Same repo — chart lives locally, already checked out
      helm template "$release_name" "$REPO_ROOT/$chart"
    else
      # TODO: Different external git repo — would require cloning at targetRevision.
      # Not currently handled; run helm template manually against the cloned repo.
      echo "SKIP: Git chart source from external repo ($repo_url) is not supported." >&2
      exit 0
    fi
    return
  fi

  # Build -f flags:
  #   $values/ prefix → resolve relative to repo root
  #   relative paths  → resolve relative to the application's directory
  local value_flags=()
  for f in "$@"; do
    if [[ "$f" == \$values/* ]]; then
      value_flags+=(-f "${f/\$values\//$REPO_ROOT/}")
    else
      value_flags+=(-f "$APP_DIR/$f")
    fi
  done

  if [[ "$repo_url" == oci://* ]]; then
    local oci_ref="$repo_url"
    # For OCI, chart may be empty or "." — repoURL is the full reference
    [[ -n "$chart" && "$chart" != "." ]] && oci_ref="${repo_url}/${chart}"
    helm template "$release_name" "$oci_ref" --version "$version" "${value_flags[@]+"${value_flags[@]}"}"
  else
    local repo_alias="tmp-$$"
    helm repo add "$repo_alias" "$repo_url" --force-update >/dev/null
    helm repo update "$repo_alias" >/dev/null
    helm template "$release_name" "${repo_alias}/${chart}" --version "$version" "${value_flags[@]+"${value_flags[@]}"}"
    helm repo remove "$repo_alias" >/dev/null
  fi
}

handle_single_source() {
  local app_file="${1}"
  local repo_url chart version release_name has_helm has_kustomize path
  repo_url=$(yq '.spec.source.repoURL // ""' "${app_file}")
  chart=$(yq '.spec.source.chart // .spec.source.path // ""' "${app_file}")
  version=$(yq '.spec.source.targetRevision // "latest"' "${app_file}")
  release_name=$(yq '.spec.source.helm.releaseName // "release"' "${app_file}")
  has_helm=$(yq '.spec.source | has("helm") or has("chart")' "${app_file}")
  has_kustomize=$(yq '.spec.source | has("kustomize")' "${app_file}")
  path=$(yq '.spec.source.path // ""' "${app_file}")

  local raw_value_files=()
  mapfile -t raw_value_files < <(yq '.spec.source.helm.valueFiles[]?' "${app_file}")

  if [ "$has_helm" = "true" ]; then
    render_helm "$repo_url" "$chart" "$version" "$release_name" "${raw_value_files[@]+"${raw_value_files[@]}"}"
  elif [ "$has_kustomize" = "true" ] || [ -n "$path" ]; then
    render_kustomize "$repo_url" "$path"
  else
    echo "SKIP: Could not determine source type for ${app_file}." >&2
    exit 0
  fi
}

handle_multi_source() {
  local app_file="${1}"
  # Match sources that are Helm-based: either has a "chart" key or a "helm" key
  # (OCI sources use helm without chart)
  local selector='select(has("chart") or has("helm"))'
  local repo_url chart version release_name
  repo_url=$(yq ".spec.sources[] | ${selector} | .repoURL" "${app_file}")
  chart=$(yq ".spec.sources[] | ${selector} | .chart // .path // \"\"" "${app_file}")
  version=$(yq ".spec.sources[] | ${selector} | .targetRevision // \"latest\"" "${app_file}")
  release_name=$(yq ".spec.sources[] | ${selector} | .helm.releaseName // \"release\"" "${app_file}")

  if [ -z "$repo_url" ]; then
    echo "SKIP: No Helm source found in multi-source Application ${app_file}." >&2
    exit 0
  fi

  # Collect value files from all sources
  local raw_value_files=()
  mapfile -t raw_value_files < <(yq '.spec.sources[].helm.valueFiles[]?' "${app_file}")

  render_helm "$repo_url" "$chart" "$version" "$release_name" "${raw_value_files[@]+"${raw_value_files[@]}"}"
}
