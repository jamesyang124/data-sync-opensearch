# Implementation Plan: Event Producer Application

**Branch**: `006-producer-app` | **Date**: 2025-12-28 | **Spec**: `/specs/006-producer-app/spec.md`
**Input**: Feature specification from `/specs/006-producer-app/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

The Test Data Service is a dedicated REST API designed to facilitate load testing and CDC pipeline validation. Unlike a traditional producer that generates its own data, this service acts as a thin, high-performance wrapper around PostgreSQL, exposing endpoints for creating, updating, and deleting entities (Users, Videos, Comments). The actual load generation, traffic patterns, and data randomization are handled externally by **k6** scripts.

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: Go 1.24 (Matching consumer-app)
**Primary Dependencies**: 
- CLI Framework: Cobra (`github.com/spf13/cobra`) - *Minimal usage for server startup*
- HTTP Router: chi (`github.com/go-chi/chi/v5`)
- Postgres Driver: pgx (`github.com/jackc/pgx/v5`)
**Storage**: PostgreSQL (Target for inserts)
**Testing**: 
- Unit/Integration: standard `testing`, `testcontainers-go`
- Load Testing: k6 (Javascript scripts in `tests/k6/`)
**Target Platform**: Linux (Docker container)
**Project Type**: API Server
**Performance Goals**: Support 500+ RPS with low overhead.
**Constraints**: Stateless, minimal external dependencies.
**Scale/Scope**: ~1k LOC. 3 main entities.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Event-Driven Integration (MANDATORY)
- **Compliant**: Yes. Writes to DB trigger CDC events.

### II. Docker-First Deployment (MANDATORY)
- **Compliant**: Yes. `Dockerfile` provided.

### III. Observability (MANDATORY)
- **Compliant**: Yes. Structured logging (Zap) and custom JSON metrics (`/metrics`).

### IV. Integration Testing (MANDATORY)
- **Compliant**: Yes. Integration tests verify DB persistence. k6 tests verify system limits.

### V. Reliability & Failure Handling (MANDATORY)
- **Compliant**: Yes. DB connection retries implemented.

### VI. Plugin Architecture for Extensibility
- **Compliant**: N/A.

## Project Structure

### Documentation (this feature)

```text
specs/006-producer-app/
├── plan.md              # This file
├── research.md          # Stack decisions
├── data-model.md        # DB Schemas
├── quickstart.md        # Run guide
├── contracts/           # API specs
└── tasks.md             # Implementation tasks
```

### Source Code (repository root)

```text
producer/
├── cmd/
│   └── producer/
│       └── main.go         # Entrypoint (Starts Server)
├── internal/
│   ├── api/                # HTTP Handlers
│   ├── config/             # Config loading
│   ├── database/           # Postgres logic
│   └── logger/             # Zap logger
├── pkg/
│   └── models/             # Domain entities
├── tests/
│   └── k6/                 # k6 load testing scripts
├── Dockerfile
├── go.mod
├── go.sum
└── Makefile
```

**Structure Decision**: Standard Go layout. `internal/generator` removed as logic moves to k6.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | | |
