# Prevent direct execution
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { echo "this lib must be sourced, not executed" >&2; exit 1; }

# Needed to source relative to local file path instead of caller path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/common.sh"

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
  local repo_url chart version release_name
  repo_url=$(yq '.spec.sources[] | select(has("chart")) | .repoURL' "${app_file}")
  chart=$(yq '.spec.sources[] | select(has("chart")) | .chart // .path // ""' "${app_file}")
  version=$(yq '.spec.sources[] | select(has("chart")) | .targetRevision // "latest"' "${app_file}")
  release_name=$(yq '.spec.sources[] | select(has("chart")) | .helm.releaseName // "release"' "${app_file}")

  if [ -z "$chart" ]; then
    echo "SKIP: No chart source found in multi-source Application ${app_file}." >&2
    exit 0
  fi

  # Collect value files from all sources
  local raw_value_files=()
  mapfile -t raw_value_files < <(yq '.spec.sources[].helm.valueFiles[]?' "${app_file}")

  render_helm "$repo_url" "$chart" "$version" "$release_name" "${raw_value_files[@]+"${raw_value_files[@]}"}"
}
