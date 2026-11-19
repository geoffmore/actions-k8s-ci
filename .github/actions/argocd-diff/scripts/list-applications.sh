#!/bin/bash
# Maps the files a PR changes or deletes to the ArgoCD Applications that own them.
#
# Inputs (environment):
#   BASE_DIR       Checkout of the base branch.
#   HEAD_DIR       Checkout of the PR branch. Default: .
#   CHANGED_FILES  Space-separated paths that exist in the PR (added, copied, modified, renamed).
#   DELETED_FILES  Space-separated paths that the PR deletes.
#
# Output (stdout), one tab-separated line per result:
#   changed<TAB><dir>/application.yaml   The Application exists in the PR. Render both sides.
#   deleted<TAB><dir>/application.yaml   The Application exists only in base. Render base only.
#   unmapped<TAB><file>                  No Application owns the file, so it is not diffed.
#
# The owner of a file is the nearest application.yaml at or above its directory.
# A deleted file no longer exists in the PR tree, so its owner comes from the base tree.
set -euo pipefail

: "${BASE_DIR:?BASE_DIR is required}"
HEAD_DIR="${HEAD_DIR:-.}"
CHANGED_FILES="${CHANGED_FILES:-}"
DELETED_FILES="${DELETED_FILES:-}"

# Prints the path of the nearest application.yaml at or above $2, relative to
# the checkout in $1. Prints nothing when there is none.
find_application() {
  local root="$1" dir="$2"
  while true; do
    if [ -f "${root}/${dir}/application.yaml" ]; then
      if [ "$dir" = "." ]; then
        echo "application.yaml"
      else
        echo "${dir}/application.yaml"
      fi
      return
    fi
    if [ "$dir" = "." ] || [ "$dir" = "/" ]; then
      return
    fi
    dir="$(dirname "$dir")"
  done
}

declare -A seen=()

# Prints one result line, once per kind and value.
emit() {
  local kind="$1" value="$2"
  if [ -n "${seen["${kind}:${value}"]:-}" ]; then
    return
  fi
  seen["${kind}:${value}"]=1
  printf '%s\t%s\n' "$kind" "$value"
}

read -r -a changed <<< "$CHANGED_FILES"
read -r -a deleted <<< "$DELETED_FILES"

for file in "${changed[@]}"; do
  app="$(find_application "$HEAD_DIR" "$(dirname "$file")")"
  if [ -n "$app" ]; then
    emit changed "$app"
  else
    emit unmapped "$file"
  fi
done

for file in "${deleted[@]}"; do
  app="$(find_application "$BASE_DIR" "$(dirname "$file")")"
  if [ -z "$app" ]; then
    emit unmapped "$file"
  elif [ -f "${HEAD_DIR}/${app}" ]; then
    # The Application survives. A file under it was deleted, so its render changes.
    emit changed "$app"
  else
    emit deleted "$app"
  fi
done
