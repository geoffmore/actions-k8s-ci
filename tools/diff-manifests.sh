#!/bin/bash
# Diffs two rendered manifest streams (multi-doc YAML) resource-by-resource.
# Resources keyed by (apiVersion, kind, namespace, name).
# Usage: ./tools/diff-manifests <base.yaml> <pr.yaml>
set -euo pipefail

# Needed to source relative to local file path instead of caller path
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/common.sh"

check_deps # TODO - move within main fn to align with other tools

BASE_FILE="${1:?Usage: argo-diff-manifests <base.yaml> <pr.yaml>}"
PR_FILE="${2:?Usage: argo-diff-manifests <base.yaml> <pr.yaml>}"

BASE_DIR="$(mktemp -d)"
PR_DIR="$(mktemp -d)"
BASE_KEYS_FILE="$(mktemp)"
PR_KEYS_FILE="$(mktemp)"
trap 'rm -rf "$BASE_DIR" "$PR_DIR" "$BASE_KEYS_FILE" "$PR_KEYS_FILE"' EXIT

split_manifest "$BASE_FILE" "$BASE_DIR"
split_manifest "$PR_FILE"   "$PR_DIR"

find "$BASE_DIR" -maxdepth 1 -name "*.yml" | awk -F/ '{print $NF}' | sort > "$BASE_KEYS_FILE" || true
find "$PR_DIR"   -maxdepth 1 -name "*.yml" | awk -F/ '{print $NF}' | sort > "$PR_KEYS_FILE"   || true

if [ ! -s "$BASE_KEYS_FILE" ] && [ ! -s "$PR_KEYS_FILE" ]; then
  echo "_No rendered output for either version (SKIP or unsupported source type)._"
  exit 0
fi

REMOVED="$(comm -23 "$BASE_KEYS_FILE" "$PR_KEYS_FILE")"
ADDED="$(  comm -13 "$BASE_KEYS_FILE" "$PR_KEYS_FILE")"
COMMON="$( comm -12 "$BASE_KEYS_FILE" "$PR_KEYS_FILE")"

key_to_label() {
  local key="${1%.yml}"
  local api kind ns name
  api="$(  printf '%s' "$key" | awk -F '__' '{print $1}' | tr '_' '/')"
  kind="$( printf '%s' "$key" | awk -F '__' '{print $2}')"
  ns="$(   printf '%s' "$key" | awk -F '__' '{print $3}')"
  name="$( printf '%s' "$key" | awk -F '__' '{print $4}')"
  if [ "$ns" = "_" ]; then
    printf '%s %s/%s' "$api" "$kind" "$name"
  else
    printf '%s %s %s/%s' "$api" "$kind" "$ns" "$name"
  fi
}

any_output=0
unchanged_count=0

if [ -n "$REMOVED" ]; then
  while IFS= read -r key; do
    [ -z "$key" ] && continue
    any_output=1
    label="$(key_to_label "$key")"
    echo "<details>"
    echo "<summary>REMOVED: <code>$label</code></summary>"
    echo ""
    echo '```diff'
    sed 's/^/- /' "$BASE_DIR/$key"
    echo '```'
    echo ""
    echo "</details>"
    echo ""
  done <<< "$REMOVED"
fi

if [ -n "$ADDED" ]; then
  while IFS= read -r key; do
    [ -z "$key" ] && continue
    any_output=1
    label="$(key_to_label "$key")"
    echo "<details>"
    echo "<summary>ADDED: <code>$label</code></summary>"
    echo ""
    echo '```diff'
    sed 's/^/+ /' "$PR_DIR/$key"
    echo '```'
    echo ""
    echo "</details>"
    echo ""
  done <<< "$ADDED"
fi

if [ -n "$COMMON" ]; then
  while IFS= read -r key; do
    [ -z "$key" ] && continue
    label="$(key_to_label "$key")"
    resource_diff="$(diff -u \
      --label "a/$label (base)" \
      --label "b/$label (pr)" \
      "$BASE_DIR/$key" "$PR_DIR/$key" || true)"
    if [ -n "$resource_diff" ]; then
      any_output=1
      echo "<details>"
      echo "<summary>MODIFIED: <code>$label</code></summary>"
      echo ""
      echo '```diff'
      echo "$resource_diff"
      echo '```'
      echo ""
      echo "</details>"
      echo ""
    else
      unchanged_count=$((unchanged_count + 1))
    fi
  done <<< "$COMMON"
fi

if [ "$unchanged_count" -gt 0 ]; then
  echo "_${unchanged_count} resource(s) unchanged (not shown)._"
  echo ""
fi

if [ "$any_output" -eq 0 ] && [ "$unchanged_count" -eq 0 ]; then
  echo "_No changes to rendered manifests._"
fi
