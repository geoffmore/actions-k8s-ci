# Prevent direct execution
# [[ "${BASH_SOURCE[0]}" == "${0}" ]] && { echo "this lib must be sourced, not executed" >&2; exit 1; }

# Needed to source relative to local file path instead of caller path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "PWD before: $PWD"
source "${SCRIPT_DIR}/common.sh"
echo "PWD after: $PWD"

# check_deps
