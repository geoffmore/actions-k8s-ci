#!/bin/bash
# Runs all ArgoCD tool tests.
# Usage: ./testdata/argocd/test.sh
# Run from the repository root.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/render-application/run-tests.sh"
echo ""
"$SCRIPT_DIR/diff-manifests/run-tests.sh"
