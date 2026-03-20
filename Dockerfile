# syntax=docker/dockerfile:1
FROM golang:1.24-alpine AS builder
RUN go install github.com/mikefarah/yq/v4@v4.45.1
RUN go install golang.stackrox.io/kube-linter/cmd/kube-linter@v0.7.2
RUN go install sigs.k8s.io/kustomize/kustomize/v5@v5.8.1

FROM alpine:3.21
RUN apk add --no-cache bash curl git tar
COPY --from=builder /go/bin/yq /go/bin/kube-linter /go/bin/kustomize /usr/local/bin/
RUN curl -sL https://get.helm.sh/helm-v4.1.3-linux-amd64.tar.gz \
    | tar xz -C /usr/local/bin --strip-components=1 linux-amd64/helm
# --verify=false required: helm-diff does not support plugin signature verification with Helm v4
# https://github.com/databus23/helm-diff?tab=readme-ov-file#install
RUN helm plugin install --verify=false https://github.com/databus23/helm-diff
