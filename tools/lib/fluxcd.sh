# Prevent direct execution
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { echo "this lib must be sourced, not executed" >&2; exit 1; }
