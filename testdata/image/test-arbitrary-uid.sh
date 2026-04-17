#!/bin/bash
# Verifies the image works when invoked with `--user $(id -u):$(id -g)` from a
# UID that has no /etc/passwd entry (as the composite actions do on CI runners).
# Regression guard: without an explicit HOME, passwd lookup fails and HOME falls
# back to /, breaking helm's wazero cache and kube-linter's config dir creation.
set -uo pipefail

pass=0
fail=0

check() {
  local label="$1" rc="$2"
  if [ "$rc" -eq 0 ]; then
    echo "PASS: $label"
    pass=$((pass + 1))
  else
    echo "FAIL: $label"
    fail=$((fail + 1))
  fi
}

echo "--- HOME handling under arbitrary UID ---"

[ "$HOME" != "/" ]
check "HOME is not / (got: $HOME)" "$?"

touch "$HOME/.write-test" 2>/dev/null && rm -f "$HOME/.write-test"
check "HOME ($HOME) is writable" "$?"

echo ""
echo "--- tools that depend on a writable HOME ---"

# `helm template` loads the installed helm-diff plugin, which initializes a
# wazero compilation cache under $HOME/.cache. Previously failed with
# `mkdir /.cache: permission denied`.
helm template testdata/helm/render-chart/local-chart >/dev/null 2>&1
check "helm template succeeds" "$?"

# kube-linter initializes a config dir under $HOME/.config on first run.
# Previously failed with `mkdir /.config: permission denied`.
kube-linter version >/dev/null 2>&1
check "kube-linter version succeeds" "$?"

echo ""
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
