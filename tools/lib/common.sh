# shellcheck shell=bash
# Prevent direct execution
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { echo "this lib must be sourced, not executed" >&2; exit 1; }

# Ensure necessary dependencies are present
function check_deps() {
  local missing=()
  for cmd in diff comm sort awk helm kustomize yq kube-linter; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  if [ ${#missing[@]} -gt 0 ]; then
    echo "ERROR: missing required tools: ${missing[*]}" >&2
    return 1
  fi
}

# split_manifest <input_file> <out_dir>
# Splits a multi-doc YAML stream into individual files under out_dir,
# keyed by (apiVersion, kind, namespace, name). Used for resource-level diffing similar to helm diff
function split_manifest() {
  local split_expr='(.apiVersion | sub("/","_")) + "__" + .kind + "__" + (.metadata.namespace // "_") + "__" + .metadata.name'
  local input_file out_dir
  input_file="$(realpath "$1")"
  out_dir="$2"
  if [ -s "$input_file" ]; then
    (cd "$out_dir" && yq -s "${split_expr}" "${input_file}")
  fi
}
