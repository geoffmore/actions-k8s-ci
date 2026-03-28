#!/bin/bash
# Runs render and lint against all test application fixtures.
# Usage: ./tools/testdata/applications/run-tests.sh
# Run from the repository root.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

pass=0
fail=0

run_test() {
  local label="$1" expected="$2"
  shift 2
  local output exit_code
  output=$("$@" 2>&1) && exit_code=0 || exit_code=$?

  case "$expected" in
    output)
      if [ -n "$output" ] && [ $exit_code -eq 0 ]; then
        echo "PASS: $label"
        pass=$((pass + 1))
      else
        echo "FAIL: $label (expected output, got exit=$exit_code)"
        echo "$output" | sed 's/^/  /'
        fail=$((fail + 1))
      fi
      ;;
    skip)
      if echo "$output" | grep -q "^SKIP:"; then
        echo "PASS: $label"
        pass=$((pass + 1))
      else
        echo "FAIL: $label (expected SKIP, got exit=$exit_code)"
        echo "$output" | sed 's/^/  /'
        fail=$((fail + 1))
      fi
      ;;
  esac
}

cd "$REPO_ROOT"

echo "--- argocd-render-application ---"
run_test "kustomize-local"      output tools/argocd-render-application.sh tools/testdata/applications/kustomize-local/application.yaml
run_test "plain-dir-local"      output tools/argocd-render-application.sh tools/testdata/applications/plain-dir-local/application.yaml
run_test "skip-unknown-source"  skip   tools/argocd-render-application.sh tools/testdata/applications/skip-unknown-source/application.yaml
run_test "skip-multi-no-chart"  skip   tools/argocd-render-application.sh tools/testdata/applications/skip-multi-no-chart/application.yaml

echo ""
echo "--- argocd-render-application --lint ---"
run_test "kustomize-local"      output tools/argocd-render-application.sh --lint tools/testdata/applications/kustomize-local/application.yaml
run_test "plain-dir-local"      output tools/argocd-render-application.sh --lint tools/testdata/applications/plain-dir-local/application.yaml
run_test "skip-unknown-source"  skip   tools/argocd-render-application.sh --lint tools/testdata/applications/skip-unknown-source/application.yaml
run_test "skip-multi-no-chart"  skip   tools/argocd-render-application.sh --lint tools/testdata/applications/skip-multi-no-chart/application.yaml

echo ""
echo "Results: $pass passed, $fail failed"
[ $fail -eq 0 ]
