# actions-k8s-ci

## What it is

This repo is intended to mimic [helm diff](https://github.com/databus23/helm-diff), but offline (from a kubernetes cluster) 
and with the ability to handle:
- Plain kubernetes manifest
- Local helm charts
- ArgoCD Applications
- eventually Flux HelmReleases

This project also handles manifest conformance with [kube-linter](https://github.com/stackrox/kube-linter) as an optional check.

## Quickstart

1. `docker build` or `docker pull public.ecr.aws/e3l5p3n5/geoffmore/actions-k8s-ci:latest`
2. Any of the tools in `tools/*.sh` should be in the containers `$PATH` without the `.sh` extension

## Actions

### `helm-diff`

Diffs rendered Helm chart manifests between the base and PR branches. Discovers affected charts from changed files, renders each scenario, and posts resource-level diffs to the job summary.

```yaml
- uses: geoffmore/actions-k8s-ci/.github/actions/helm-diff@main
  with:
    # Required: glob scoping which changed files trigger a diff
    paths: charts/**

    # Optional: space-separated extra values files (relative to chart root).
    # Each file is rendered as an independent scenario on top of values.yaml.
    # Files absent from a chart are silently skipped.
    extra-values: stage.values.yaml test.values.yaml

    # Optional: run kube-linter on each PR render; fail if issues found
    lint: true
    kube-linter-config: .kube-linter.yaml
```

For each changed chart, the summary contains one diff section per render scenario:

```
## Manifest Diff: `charts/foo`
## Manifest Diff: `charts/foo` (stage.values.yaml)
## Manifest Diff: `charts/foo` (test.values.yaml)
```

### `argocd-diff`

Diffs rendered ArgoCD Application manifests between the base and PR branches. Walks up the directory tree from each changed file to find the nearest `application.yaml`.

```yaml
- uses: geoffmore/actions-k8s-ci/.github/actions/argocd-diff@main
  with:
    paths: argocd/**

    # Optional: run kube-linter on each PR render; fail if issues found
    lint: true
    kube-linter-config: .kube-linter.yaml
```

## Tools

All tools are available in the container at `public.ecr.aws/e3l5p3n5/geoffmore/actions-k8s-ci:latest`.

| Tool | Description |
|------|-------------|
| `helm-render-chart` | Renders a local Helm chart to stdout. Accepts `--extra-values <file>` (relative to chart root, silently skipped if absent), `--release-name`, `--lint`, `--lint-config`. |
| `argocd-render-application` | Renders an ArgoCD Application manifest to stdout. Handles Helm (HTTP, OCI) and Kustomize sources. Unsupported sources emit `SKIP:` and exit 0. |
| `diff-manifests` | Diffs two rendered multi-document YAML streams resource-by-resource, keyed by `(apiVersion, kind, namespace, name)`. Outputs GitHub-flavored Markdown for job summaries. |

## Running tests locally

```bash
./test.sh           # build image and run full test suite
./test.sh --no-cache
```

## Image

Built from `main` on every push that touches the `Dockerfile`. Published to:

```
public.ecr.aws/e3l5p3n5/geoffmore/actions-k8s-ci:latest
public.ecr.aws/e3l5p3n5/geoffmore/actions-k8s-ci:<git-sha>
public.ecr.aws/e3l5p3n5/geoffmore/actions-k8s-ci:r<run-number>
```
