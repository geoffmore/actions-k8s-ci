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
    error)
      if [ $exit_code -ne 0 ]; then
        echo "PASS: $label"
        pass=$((pass + 1))
      else
        echo "FAIL: $label (expected non-zero exit, got exit=$exit_code)"
        fail=$((fail + 1))
      fi
      ;;
  esac
}

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

cd "$REPO_ROOT"

CHART="testdata/helm/render-chart/local-chart"

echo "--- helm-render-chart ---"
output="$(tools/helm-render-chart.sh "$CHART" 2>&1)"
check "default (values.yaml only)"    "extraKey: default"    "$output"

output="$(tools/helm-render-chart.sh --extra-values stage.values.yaml "$CHART" 2>&1)"
check "extra-values stage.values.yaml" "extraKey: stage"     "$output"

output="$(tools/helm-render-chart.sh --extra-values test.values.yaml "$CHART" 2>&1)"
check "extra-values test.values.yaml"  "extraKey: test"      "$output"

output="$(tools/helm-render-chart.sh --extra-values values-override.yaml "$CHART" 2>&1)"
check "extra-values values-override"   "extraKey: overridden" "$output"

# Missing extra-values file should be silently skipped, falling back to defaults
output="$(tools/helm-render-chart.sh --extra-values nonexistent.values.yaml "$CHART" 2>&1)"
check "extra-values missing file skipped" "extraKey: default" "$output"

echo ""
echo "--- helm-render-chart (negative) ---"
run_test "nonexistent chart"    error tools/helm-render-chart.sh /nonexistent/chart

echo ""
echo "--- helm-render-chart --lint ---"
run_test "default"              output tools/helm-render-chart.sh --lint "$CHART"
run_test "extra-values stage"   output tools/helm-render-chart.sh --lint --extra-values stage.values.yaml "$CHART"
run_test "extra-values test"    output tools/helm-render-chart.sh --lint --extra-values test.values.yaml "$CHART"

echo ""
echo "Results: $pass passed, $fail failed"
[ $fail -eq 0 ]
