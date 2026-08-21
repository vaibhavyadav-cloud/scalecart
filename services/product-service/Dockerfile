# --- Stage 1: build a static binary ---
FROM golang:1.22-alpine AS builder
WORKDIR /app
RUN apk add --no-cache git
COPY go.mod ./
RUN go mod download 2>/dev/null || true
COPY . .
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /product-service ./cmd

# --- Stage 2: distroless runtime - no shell, no package manager, minimal
# attack surface. This is what Trivy scans in the CI pipeline and it
# typically comes back near-zero CVEs compared to a full OS base image. ---
FROM gcr.io/distroless/static-debian12:nonroot AS runtime
WORKDIR /
COPY --from=builder /product-service /product-service
USER nonroot:nonroot
EXPOSE 4002
ENTRYPOINT ["/product-service"]
