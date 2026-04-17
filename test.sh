#!/bin/bash
# Builds the image locally and runs the test suite against the current working tree.
# Usage: ./test.sh [--no-cache]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="actions-k8s-ci:local-test"

BUILD_ARGS=()
[[ "${1:-}" == "--no-cache" ]] && BUILD_ARGS+=(--no-cache)
docker build "${BUILD_ARGS[@]}" -t "$IMAGE" "$SCRIPT_DIR"

run() {
  docker run --rm \
    -v "$SCRIPT_DIR:/repo" \
    -w /repo \
    "$IMAGE" \
    "$@"
}

# Mirrors how the composite actions invoke the image: overrides --user to the
# caller's UID so bind-mounted workspace writes stay owned by the runner.
run_as_runner() {
  docker run --rm --user "$(id -u):$(id -g)" \
    -v "$SCRIPT_DIR:/repo" \
    -w /repo \
    "$IMAGE" \
    "$@"
}

echo ""
run testdata/image/test.sh

echo ""
run_as_runner testdata/image/test-arbitrary-uid.sh

echo ""
run testdata/argocd/test.sh

echo ""
run testdata/diff-manifests/run-tests.sh

echo ""
run testdata/helm/test.sh
