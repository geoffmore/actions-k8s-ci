#!/bin/bash
# Runs helm-render-chart against test fixtures.
# Usage: ./testdata/helm/render-chart/run-tests.sh
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
        while IFS= read -r line; do echo "  $line"; done <<< "$output"
        fail=$((fail + 1))
      fi
      ;;
  esac
}

cd "$REPO_ROOT"

CHART="testdata/helm/render-chart/local-chart"

echo "--- helm-render-chart ---"
run_test "local-chart"      output tools/helm-render-chart.sh "$CHART"

echo ""
echo "--- helm-render-chart --lint ---"
run_test "local-chart"      output tools/helm-render-chart.sh --lint "$CHART"

echo ""
echo "Results: $pass passed, $fail failed"
[ $fail -eq 0 ]
