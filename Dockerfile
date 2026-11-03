# Build stage
FROM --platform=$BUILDPLATFORM golang:1.24 AS builder

ARG TARGETOS
ARG TARGETARCH

WORKDIR /app

# Copy go mod files first for better caching
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the binary for the platform being built, so the image can be multi-arch.
RUN CGO_ENABLED=0 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH:-amd64} \
    go build -ldflags="-s -w" -o numa-resource-plugin ./cmd/plugin

# Runtime stage: Red Hat UBI, which certification requires as the base image.
FROM registry.access.redhat.com/ubi10/ubi-minimal:10.2

ARG VERSION=dev
ARG RELEASE=1

WORKDIR /

COPY --from=builder /app/numa-resource-plugin /numa-resource-plugin
COPY LICENSE /licenses/LICENSE

# Non-root by default, as certification requires. The plugin creates its socket
# in kubelet's root-owned /var/lib/kubelet/device-plugins, so the DaemonSet that
# deploys it sets runAsUser: 0.
USER 65532:65532

ENTRYPOINT ["/numa-resource-plugin"]

LABEL name="numa-resource-plugin" \
      vendor="simplyblock" \
      maintainer="developers@simplyblock.io" \
      version="${VERSION}" \
      release="${RELEASE}" \
      summary="Kubernetes device plugin that advertises NUMA nodes as extended resources." \
      description="Fork of ChessCom/k8s-numa-resource-plugin. Registers each NUMA node of a worker as a schedulable extended resource, so pods can request placement on one NUMA node."
