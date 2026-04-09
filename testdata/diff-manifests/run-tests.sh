#!/bin/bash
# Runs diff-manifests against test fixtures and checks output.
# Usage: ./testdata/diff-manifests/run-tests.sh
# Run from the repository root.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

pass=0
fail=0

check() {
  local label="$1" pattern="$2" output="$3"
  if echo "$output" | grep -q "$pattern"; then
    echo "PASS: $label"
    pass=$((pass + 1))
  else
    echo "FAIL: $label (pattern not found: $pattern)"
    while IFS= read -r line; do echo "  $line"; done <<< "$output"
    fail=$((fail + 1))
  fi
}

check_absent() {
  local label="$1" pattern="$2" output="$3"
  if echo "$output" | grep -q "$pattern"; then
    echo "FAIL: $label (unexpected pattern found: $pattern)"
    while IFS= read -r line; do echo "  $line"; done <<< "$output"
    fail=$((fail + 1))
  else
    echo "PASS: $label"
    pass=$((pass + 1))
  fi
}

cd "$REPO_ROOT"

BASE="testdata/diff-manifests/base.yaml"
PR="testdata/diff-manifests/pr.yaml"

echo "--- diff-manifests ---"
output="$(tools/diff-manifests.sh "$BASE" "$PR" 2>&1)"

check        "removed Service/web"                  "REMOVED.*Service.*web"             "$output"
check        "added ServiceAccount/web"             "ADDED.*ServiceAccount.*web"        "$output"
check        "modified Deployment/web"              "MODIFIED.*Deployment.*web"         "$output"
check        "modified ConfigMap/config"            "MODIFIED.*ConfigMap.*config"       "$output"
check        "unchanged count reported"             "resource(s) unchanged"             "$output"
check_absent "unchanged ConfigMap not shown as MODIFIED" "MODIFIED.*ConfigMap.*unchanged" "$output"

echo ""
echo "Results: $pass passed, $fail failed"
[ $fail -eq 0 ]
