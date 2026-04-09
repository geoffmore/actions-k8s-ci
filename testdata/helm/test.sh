#!/bin/bash
# Runs all Helm tool tests.
# Usage: ./testdata/helm/test.sh
# Run from the repository root.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/render-chart/run-tests.sh"
