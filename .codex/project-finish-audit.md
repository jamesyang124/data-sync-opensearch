# Project Finish Audit

Last updated: 2026-05-24

## Executive Summary

The repository has most component scaffolding and local tooling in place, but the project is not finish-ready because the end-to-end data contract is inconsistent across producer, consumer, OpenSearch, benchmark payloads, and specs.

The highest-priority finish work is to choose and enforce one canonical entity contract. Current goal state treats `postgres/init/01-create-schema.sql` as authoritative. Under that choice, the producer, producer spec/contracts, consumer transforms, consumer tests, OpenSearch mappings, and benchmark builders need alignment.

## Evidence Snapshot

- Spec task completion by checklist:
  - `001-postgres-datasource-setup`: 48/48 checked.
  - `002-cdc-setup`: 22/27 checked; 5 TODOs remain despite the file also claiming 100% complete.
  - `003-kafka-validation`: 30/39 checked; 9 validation/report/repeatability tasks remain.
  - `004-opensearch-setup`: 62/62 checked.
  - `005-consumer-app`: 34/46 checked; 12 deferred/incomplete validation and integration tasks remain.
  - `006-producer-app`: 25/25 checked, but code and contracts are stale relative to the root Postgres schema.
  - `007-xk6-benchmark`: 22/22 checked, with video update/delete and comments explicitly deferred.
- Producer baseline:
  - `GOCACHE=/tmp/data-sync-go-cache go test ./cmd/... ./internal/... ./pkg/...`: PASS, no test files.
  - `GOCACHE=/tmp/data-sync-go-cache go test ./...`: BLOCKED by missing Docker/testcontainers runtime (`rootless Docker not found`), not by an assertion failure.
- Consumer baseline:
  - `go test ./...`: PASS for current unit tests.
  - Current tests are weak for finish readiness because they mostly validate raw field extraction and include fields that are not in the canonical Postgres schema.

## Contract Alignment Gaps

Canonical schema from `postgres/init/01-create-schema.sql`:

- `videos(video_id, title, category, created_at, updated_at)`
- `users(channel_id, channel_name, created_at, updated_at)`
- `comments(comment_id, video_id, channel_id, comment_text, likes, replies, published_at, sentiment_label, country_code, created_at, updated_at)`

Known drift:

- Producer models and API contracts use UUID-style `user_id`, `username`, `email`, video `description`, and `duration`.
- Producer routes only expose User CRUD and Video create; Video update/delete and all Comments CRUD are missing.
- Producer tests create temporary tables that match the stale producer schema, not the canonical Postgres schema.
- Consumer transforms expect mixed fields:
  - User transform reads `channel_id` but maps `username`, `email`, and `subscriber_count`.
  - Video transform reads `user_id`, `description`, `duration_seconds`, `view_count`, and `like_count`.
  - Comment transform reads `user_id`, `parent_comment_id`, and `like_count`, while canonical Postgres has `channel_id`, `likes`, `replies`, `published_at`, `sentiment_label`, and `country_code`.
- OpenSearch mappings also mix canonical and non-canonical fields.
- Benchmark faker/client payloads are still based on the stale producer API shape.

## Finish Work Required

### P0 - Canonical Contract Cleanup

- Update `specs/006-producer-app` API/data-model docs to match `postgres/init/01-create-schema.sql`.
- Decide OpenSearch document field names for canonical fields and apply consistently across mappings, consumer transforms, and tests.
- Update benchmark builders only after producer API shape is corrected.

### P1 - Producer Completion

- Replace stale UUID/user-email producer models with canonical `channel_id`, `channel_name`, `video_id`, `category`, and canonical comment fields.
- Update DB methods for create/update/delete on users, videos, and comments.
- Add routes and handlers:
  - `PUT /api/v1/videos/{id}`
  - `DELETE /api/v1/videos/{id}`
  - `POST /api/v1/comments`
  - `PUT /api/v1/comments/{id}`
  - `DELETE /api/v1/comments/{id}`
- Update producer integration and contract tests to initialize schema from `postgres/init/01-create-schema.sql`, not hand-written stale test tables.
- Add validation for bad JSON, missing entities, FK violations, and constraint conflicts.

### P2 - Consumer Finish Readiness

- Align transforms and unit tests to canonical Postgres fields and selected OpenSearch document shape.
- Add or complete the deferred end-to-end pipeline test: PostgreSQL insert/update/delete -> Debezium/Kafka -> consumer -> OpenSearch document/index state.
- Add failure and offset-resume tests:
  - OpenSearch unavailable -> retry/DLQ behavior.
  - Consumer restart -> resumes from committed offset without loss/duplicate corruption.
- Validate `/health` and `/metrics` endpoints against a running stack.

### P3 - CDC/Kafka Validation Closure

- Resolve Debezium task-file contradiction: either mark remaining tests done with evidence or leave feature status incomplete.
- Run or repair Debezium tests:
  - connector registration,
  - CDC capture,
  - offset recovery,
  - US1 integration suite.
- Complete Kafka validation tasks:
  - run performance suite,
  - run delivery suite,
  - generate performance and delivery reports,
  - verify repeatability and success criteria.

### P4 - Benchmark And External Report

- After producer and consumer contract alignment, update benchmark payloads and workload only if the new endpoints are ready.
- Produce a minimal review artifact before declaring finish:
  - preferred: low-rate benchmark report such as `BENCHMARK_TARGET_RPS=20 BENCHMARK_DURATION=15s make -C benchmark run-sustained`;
  - acceptable substitute if benchmark stack is unavailable: focused smoke report showing API CRUD plus PostgreSQL persistence and, separately, pipeline sync to OpenSearch.
- Keep full 500 RPS and stress runs as later performance gates, not the first correctness proof.

## Suggested Next Slice

Start with producer contract alignment because it feeds benchmark payloads and CDC event shapes:

1. Update producer models and contracts to canonical schema.
2. Update producer tests to use `postgres/init/01-create-schema.sql`.
3. Implement missing video/comment endpoints.
4. Run producer unit/package tests and Docker-backed integration tests.
5. Run `/review` or equivalent review before expanding benchmark workload.
