# Tasks: Test Data Service

**Feature Branch**: `006-producer-app`
**Status**: Pending

## Phase 1: Setup
**Goal**: Initialize the project structure and shared infrastructure (Config, Logger, Docker).
**Scope**: Project scaffolding, `internal/config`, `internal/logger`, `Dockerfile`.

- [X] T001 Initialize Go module and project structure in `producer/`
- [X] T002 Implement configuration loading (Env/Flags) in `producer/internal/config/config.go`
- [X] T003 Implement structured logging (Zap) in `producer/internal/logger/logger.go`
- [X] T004 Create `Dockerfile` for the producer service in `producer/Dockerfile`
- [X] T005 Create `Makefile` with build/test/run commands in `producer/Makefile`
- [X] T006 Implement entrypoint with Cobra `serve` command in `producer/cmd/producer/main.go`

## Phase 2: Foundational
**Goal**: Implement core database connectivity and basic server infrastructure.
**Scope**: `internal/database`, `internal/api` (router setup), `pkg/models`.
**Dependencies**: Phase 1

- [X] T007 Define domain models (User, Video, Comment) in `producer/pkg/models/models.go`
- [X] T008 Implement PostgreSQL connection pool logic (pgx) in `producer/internal/database/postgres.go`
- [X] T009 Implement basic Chi router setup with middleware (Logger, Recoverer) in `producer/internal/api/router.go`
- [X] T010 Implement `/health` endpoint handler in `producer/internal/api/health.go`
- [X] T011 [P] Implement `/metrics` endpoint (JSON) in `producer/internal/api/metrics.go`

## Phase 3: REST API for Data Management (User Story 1)
**Goal**: Expose CRUD endpoints for Users, Videos, and Comments to enable data seeding.
**Scope**: `internal/api` handlers, DB queries.
**Dependencies**: Phase 2

- [X] T012 [US1] Implement DB Insert/Update/Delete methods for Users in `producer/internal/database/users.go`
- [X] T013 [US1] Implement DB Insert methods for Videos in `producer/internal/database/videos.go`
- [X] T014 [US1] Implement HTTP Handlers for User CRUD (POST, PUT, DELETE) with error mapping (400/404/409) in `producer/internal/api/users_handler.go`
- [X] T015 [US1] Implement HTTP Handler for Video Creation (POST) with error mapping in `producer/internal/api/videos_handler.go`
- [X] T016 [US1] Register all entity routes in `producer/internal/api/router.go`
- [X] T017 [US1] [P] Create integration test suite using testcontainers to verify happy paths (Create/Update/Delete) and edge cases (400/409) in `producer/tests/integration/api_test.go`
- [X] T025 [US1] Implement contract tests to validate JSON request/response schemas against `contracts/api.md` specs in `producer/tests/contract/api_contract_test.go`

## Phase 4: High-Throughput Load Testing Support (User Story 2)
**Goal**: Validate and tune performance with k6 scripts.
**Scope**: k6 scripts, performance tuning.
**Dependencies**: Phase 3

- [X] T018 [US2] Create k6 load test script for User creation flow in `producer/tests/k6/users_load.js`
- [X] T019 [US2] Create k6 load test script for Mixed workload (Create User -> Create Video) in `producer/tests/k6/mixed_load.js`
- [X] T020 [US2] Add graceful shutdown logic to server in `producer/cmd/producer/main.go`
- [X] T021 [US2] [P] Document k6 usage in `producer/README.md`

## Phase 5: Polish & Cross-Cutting
**Goal**: Finalize documentation and verify CI/CD readiness.
**Dependencies**: Phase 4

- [X] T022 Update `docker-compose.yml` in repo root to include producer service
- [X] T023 Update root `Makefile` to include producer build steps
- [X] T024 Finalize `producer/README.md` with configuration and API docs

## Dependencies

1. **Phase 1 (Setup)**: Unblocks everything.
2. **Phase 2 (Foundational)**: Unblocks API implementation.
3. **Phase 3 (US1)**: Unblocks Load Testing (US2).
4. **Phase 4 (US2)**: Depends on working API.

## Parallel Execution Opportunities

- **T011 (Metrics)** can be done parallel to **T010 (Health)**.
- **T017 (Integration Test)** can be written parallel to handlers (T014, T015).
- **T021 (Docs)** can be done parallel to script writing (T018, T019).

## Implementation Strategy

1. **MVP**: Complete Phase 1 & 2 + T012, T014 (User Create). This proves end-to-end flow.
2. **Feature Complete**: Finish Phase 3 (All entities).
3. **Verification**: Execute Phase 4 (Load Tests) to validate 500 RPS target.
