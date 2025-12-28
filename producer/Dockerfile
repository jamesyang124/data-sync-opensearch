# Build stage
FROM golang:1.24-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache make

# Copy go mod and sum files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN make build

# Final stage
FROM alpine:3.19

WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache ca-certificates

# Copy binary from builder
COPY --from=builder /app/bin/producer /app/producer

# Expose ports
EXPOSE 8080 9090

# Set entrypoint
ENTRYPOINT ["/app/producer"]
CMD ["serve"]
