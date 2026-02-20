# Stage 1: Build custom k6 binary with xk6-faker extension
FROM grafana/xk6 AS builder

RUN xk6 build \
    --with github.com/grafana/xk6-faker@latest \
    --output /k6

# Stage 2: Minimal k6 runner image with the custom binary
FROM grafana/k6:latest

COPY --from=builder /k6 /usr/bin/k6
