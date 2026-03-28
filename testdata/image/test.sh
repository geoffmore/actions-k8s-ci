#!/bin/bash
# Smoke tests for the built image: verifies binaries, symlinks, and bundled config.
# Runs inside the container with no bind mount.
set -euo pipefail

pass=0
fail=0

check_cmd() {
  local label="$1" cmd="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "PASS: $label"
    pass=$((pass + 1))
  else
    echo "FAIL: $label (command not found: $cmd)"
    fail=$((fail + 1))
  fi
}

check_file() {
  local label="$1" path="$2"
  if [ -f "$path" ]; then
    echo "PASS: $label"
    pass=$((pass + 1))
  else
    echo "FAIL: $label (file not found: $path)"
    fail=$((fail + 1))
  fi
}

echo "--- image binaries ---"
check_cmd "yq"                    yq
check_cmd "kube-linter"           kube-linter
check_cmd "kustomize"             kustomize
check_cmd "helm"                  helm

echo ""
echo "--- symlinked scripts ---"
check_cmd "argocd-render-application" argocd-render-application
check_cmd "argocd-diff-manifests"     argocd-diff-manifests

echo ""
echo "--- bundled config ---"
check_file "bundled .kube-linter.yaml" /usr/local/lib/actions-k8s-ci/.kube-linter.yaml

echo ""
echo "Results: $pass passed, $fail failed"
[ $fail -eq 0 ]
