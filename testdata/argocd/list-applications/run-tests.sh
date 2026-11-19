#!/bin/bash
# Runs list-applications.sh against base/head fixture trees.
# Usage: ./testdata/argocd/list-applications/run-tests.sh
# Run from the repository root.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

SCRIPT=".github/actions/argocd-diff/scripts/list-applications.sh"
FIXTURES="testdata/argocd/list-applications"

pass=0
fail=0

# check <label> <scenario> <changed files> <deleted files> <expected output>
# Runs the script with the base and head trees of <scenario> and compares stdout.
check() {
  local label="$1" scenario="$2" changed="$3" deleted="$4" expected="$5"
  local actual rc
  actual="$(BASE_DIR="$FIXTURES/$scenario/base" HEAD_DIR="$FIXTURES/$scenario/head" \
    CHANGED_FILES="$changed" DELETED_FILES="$deleted" "$BASH" "$SCRIPT" 2>&1)" && rc=0 || rc=$?

  if [ "$rc" -eq 0 ] && [ "$actual" = "$expected" ]; then
    echo "PASS: $label"
    pass=$((pass + 1))
  else
    echo "FAIL: $label (exit=$rc)"
    echo "  expected:"
    while IFS= read -r line; do echo "    $line"; done <<< "$expected"
    echo "  actual:"
    while IFS= read -r line; do echo "    $line"; done <<< "$actual"
    fail=$((fail + 1))
  fi
}

cd "$REPO_ROOT"

echo "--- list-applications ---"

check "changed file maps to the nearest Application" repo \
  "argocd/apps/modified/application.yaml argocd/apps/kept/resources/kustomization.yaml" "" \
  $'changed\targocd/apps/modified/application.yaml\nchanged\targocd/apps/kept/application.yaml'

check "deleted file under a surviving Application is a change" repo \
  "" "argocd/apps/kept/resources/old.yaml" \
  $'changed\targocd/apps/kept/application.yaml'

check "changed and deleted files of one Application print it once" repo \
  "argocd/apps/kept/resources/kustomization.yaml" "argocd/apps/kept/resources/old.yaml" \
  $'changed\targocd/apps/kept/application.yaml'

check "deleted Application is reported once for all of its files" repo \
  "" "argocd/apps/gone/application.yaml argocd/apps/gone/resources/kustomization.yaml" \
  $'deleted\targocd/apps/gone/application.yaml'

check "deleted nested Application resolves to the child, not the parent" repo \
  "" "argocd/apps/nested/child/application.yaml argocd/apps/nested/child/resources/res.yaml" \
  $'deleted\targocd/apps/nested/child/application.yaml'

check "changed file with no Application above it is unmapped" repo \
  "argocd/apps/generated/overlay/kustomization.yaml" "" \
  $'unmapped\targocd/apps/generated/overlay/kustomization.yaml'

check "deleted file with no Application above it is unmapped" repo \
  "" "argocd/apps/orphan/notes.txt" \
  $'unmapped\targocd/apps/orphan/notes.txt'

check "an application.yaml at the repository root owns root-level files" root \
  "values.yaml" "" \
  $'changed\tapplication.yaml'

check "no files print nothing" repo "" "" ""

echo ""
echo "--- list-applications (missing BASE_DIR) ---"
if (cd "$REPO_ROOT" && env -u BASE_DIR "$BASH" "$SCRIPT" > /dev/null 2>&1); then
  echo "FAIL: missing BASE_DIR must exit non-zero"
  fail=$((fail + 1))
else
  echo "PASS: missing BASE_DIR exits non-zero"
  pass=$((pass + 1))
fi

echo ""
echo "Results: $pass passed, $fail failed"
[ $fail -eq 0 ]
