# Research & Decisions: Event Producer Application

**Status**: Phase 0 Complete
**Date**: 2025-12-28

## 1. CLI Framework

**Decision**: **Cobra** (github.com/spf13/cobra)

**Rationale**:
- Although the requirement is "lightweight", the application has multiple distinct modes (generate once, load test duration, different entities).
- Cobra provides standard, robust argument parsing, help generation (`--help`), and structure for subcommands if needed (e.g., `producer generate` vs `producer version`).
- It is the de-facto standard for Go CLIs (Kubernetes, Docker, etc.), making it familiar for maintainers.

**Alternatives Considered**:
- **stdlib `flag`**: Zero dependency, but handling subcommands and complex flag relationships (e.g., specific flags for load testing vs one-off) requires writing boilerplate validation logic.
- **urfave/cli**: Another popular option, but Cobra is more widely used in the cloud-native ecosystem.

## 2. PostgreSQL Driver

**Decision**: **pgx** (github.com/jackc/pgx/v5)

**Rationale**:
- **Performance**: `pgx` is significantly faster than `lib/pq` and other drivers.
- **Bulk Insert Support**: Native support for the PostgreSQL `COPY` protocol (via `CopyFrom`) is essential for meeting the high-throughput requirements (1000 events/30s) and batching NFRs efficiently.
- **Maintenance**: `lib/pq` is in maintenance mode. `pgx` is actively developed and recommended.

**Alternatives Considered**:
- **lib/pq**: "Standard" but essentially frozen. Slower.
- **database/sql** (generic): We will use `pgx` directly or via stdlib wrapper, but direct `pgx` usage allows access to `CopyFrom` for bulk performance.

## 3. Observability Strategy

**Decision**: **Structured Logging (Zap) + Custom JSON Metrics**

**Rationale**:
- **Zap**: Matches the consumer application.
- **JSON Metrics**: The consumer service implements a simple JSON `/metrics` endpoint. To maintain consistency and avoid introducing heavy Prometheus dependencies for a test tool, we will mirror this approach.
- **k6**: k6 will provide the detailed load testing reports (latency histograms, percentiles). The internal `/metrics` endpoint is strictly for operational health (DB pool status, error counts).

**Alternatives Considered**:
- **Prometheus**: Overkill for this specific tool and inconsistent with the consumer's current implementation.

## 4. HTTP Router

**Decision**: **chi** (github.com/go-chi/chi/v5)

**Rationale**:
- **Lightweight**: Minimalist router that is idiomatic to the Go standard library (`net/http`).
- **Middleware**: Good ecosystem of middleware (logging, recovering, etc.) which is useful for the API server.
- **Performance**: Very fast, zero allocations for routing.

**Alternatives Considered**:
- **Gin**: Powerful but opinionated and heavier.
- **Gorilla Mux**: In maintenance mode.

## 5. Directory Structure Alignment

**Decision**:
- Place `producer/` at the root, parallel to `consumer/`.
- Use `cmd/producer/main.go` for the entry point.
- Use `internal/api/` for HTTP handlers.
- Use `tests/k6/` for load testing scripts.

**Rationale**:
- Consistency with `consumer` module.
- Separation of CLI logic (`cmd/`) and Server logic (`internal/api`).