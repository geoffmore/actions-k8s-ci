# syntax=docker/dockerfile:1
FROM golang:1.24-alpine@sha256:8bee1901f1e530bfb4a7850aa7a479d17ae3a18beb6e09064ed54cfd245b7191 AS builder
RUN go install github.com/mikefarah/yq/v4@v4.45.1
RUN go install golang.stackrox.io/kube-linter/cmd/kube-linter@v0.7.2
RUN go install sigs.k8s.io/kustomize/kustomize/v5@v5.8.1

FROM alpine:3.21@sha256:c3f8e73fdb79deaebaa2037150150191b9dcbfba68b4a46d70103204c53f4709
RUN apk add --no-cache bash curl git tar
COPY --from=builder /go/bin/yq /go/bin/kube-linter /go/bin/kustomize /usr/local/bin/
ARG TARGETARCH
RUN curl -sL "https://get.helm.sh/helm-v4.1.3-linux-${TARGETARCH}.tar.gz" \
    | tar xz -C /usr/local/bin --strip-components=1 "linux-${TARGETARCH}/helm"
# Store helm plugins in a system-wide path accessible to any runtime UID
ENV HELM_PLUGINS=/usr/local/share/helm/plugins
# --verify=false required: helm-diff does not support plugin signature verification with Helm v4
# https://github.com/databus23/helm-diff?tab=readme-ov-file#install
RUN helm plugin install --verify=false --version v3.15.4 https://github.com/databus23/helm-diff
COPY tools/ /usr/local/lib/actions-k8s-ci/
COPY .kube-linter.yaml /usr/local/lib/actions-k8s-ci/.kube-linter.yaml
RUN ln -s /usr/local/lib/actions-k8s-ci/argocd-render-application.sh /usr/local/bin/argocd-render-application \
 && ln -s /usr/local/lib/actions-k8s-ci/diff-manifests.sh /usr/local/bin/diff-manifests \
 && ln -s /usr/local/lib/actions-k8s-ci/helm-render-chart.sh /usr/local/bin/helm-render-chart
RUN addgroup -g 1000 ci && adduser -D -u 1000 -G ci ci
USER ci
# Callers override --user to the runner UID to preserve bind-mount ownership.
# That UID has no /etc/passwd entry in this image, so HOME would fall back to /,
# breaking helm's wazero plugin cache ($HOME/.cache/helm/wazero-build) and
# kube-linter's config dir ($HOME/.config) with "mkdir: permission denied".
# Pinning HOME to a world-writable path keeps the image UID-agnostic.
ENV HOME=/tmp
# Allow git to operate on bind-mounted workspaces owned by a different UID
# (e.g. CI runners). This disables git's ownership checks globally — acceptable
# for a single-purpose CI image but this image should not be used interactively.
RUN git config --global --add safe.directory '*'
