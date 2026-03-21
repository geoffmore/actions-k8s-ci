# Prevent direct execution
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { echo "this lib must be sourced, not executed" >&2; exit 1; }

function check_deps() {
  local missing=()
  for cmd in diff common sort awk helm kustomize yq kube-linter; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  if [ ${#missing[@]} -gt 0 ]; then
    echo "ERROR: missing required tools: ${missing[*]}" >&2
    exit 1
  fi
}
