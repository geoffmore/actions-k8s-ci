# Contributing to actions-k8s-ci

Thanks for your interest in contributing! This document explains how to report issues, suggest features, and submit changes.

## Code of Conduct

Please be respectful and constructive in all interactions. We follow the [Go Community Code of Conduct](https://go.dev/conduct).

## Reporting Bugs

Found a bug? Please [open an issue](https://github.com/geoffmore/actions-k8s-ci/issues/new?template=bug_report.md) and include:

- What you expected to happen
- What actually happened
- Steps to reproduce (workflow snippet, chart structure, etc.)
- Relevant logs or job summary output

## Requesting Features

Have an idea? [Open a feature request](https://github.com/geoffmore/actions-k8s-ci/issues/new?template=feature_request.md) describing:

- The problem you're trying to solve
- Your proposed solution
- Any alternatives you've considered

## Submitting Changes

1. Fork the repository and create a branch from `main`
2. Make your changes
3. Run the test suite locally:
   ```bash
   ./test.sh
   ```
4. Run `shellcheck` on any modified shell scripts
5. Open a pull request with a clear description of what changed and why

### Style

- Shell scripts should pass `shellcheck` cleanly
- Use `set -euo pipefail` in all scripts
- Source shared functions from `tools/lib/` rather than duplicating logic
- Pin external action references to SHA in workflow files
