# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased] — 2026-05-24

### Added

#### Producer API
- Full CRUD REST API for **users**, **videos**, and **comments** (`producer/internal/api/`, `producer/internal/database/`)
- Updated shared model types to align with CDC event schema (`producer/pkg/models/`)
- Contract tests and integration test suite covering all three resource endpoints
- k6 mixed-load and user-load scripts updated to exercise the expanded API surface

#### Consumer — CDC Pipeline
- Extended `cdc_event.go` to carry all three entity types (users, videos, comments) with full field coverage
- Transform layers updated for comment, user, and video entities with unit test coverage
- **Dead-letter queue (DLQ)**: undeliverable CDC events are routed to a DLQ topic instead of blocking the pipeline (`consumer/internal/kafka/dlq.go`)
- Delivery verification hardened in handler and consumer with corresponding test coverage
- **Stale CDC delete guard**: the OpenSearch indexer now skips delete operations whose sequence number is behind the document's current version, preventing out-of-order deletes from clobbering later writes
- OpenSearch indexer retry logic with test coverage (`consumer/internal/opensearch/indexer_test.go`)
- Worker pool and backpressure handler simplified

#### OpenSearch
- Index mappings updated for `users`, `videos`, and `comments` indices to align with extended CDC model

#### Ops Console
- New Go CLI tool at `ops-console/` providing an HTTP API for service diagnostics, consumer replica scaling, and benchmark triggering
- Endpoints: `/api/status`, `/api/scale`, `/api/benchmark`
- Read consistency check integrated into the console

#### Benchmark
- k6 scenario scripts (ramp-up, stress, sustained-load) extended with a shared `faker.js` library for realistic, Faker-driven payload generation
- `client.js` updated to cover comments API; thresholds and scenario parameters tuned

#### Scripts & Ops
- `scripts/scale-cdc-topics.sh`: automates Kafka topic partition scaling for the CDC pipeline
- `scripts/verify-read-consistency.sh`: end-to-end read consistency verification — drives producer CUD operations, fires concurrent OpenSearch reads, and asserts final document state
- `docs/consumer-scale-plan.md`: runbook for scaling CDC consumers and topic partitions under increased load

#### Infra
- `docker-compose.yml` extended with ops-console service, consumer tuning env vars, and Kafbat UI
- `Makefile` targets added: `verify-read-consistency`, `scale-cdc-topics`, `start-ops-console`
- `.env.example` updated with consumer tuning knobs (`CONSUMER_WORKER_COUNT`, `CONSUMER_BATCH_SIZE`, etc.) and ops-console port

### Changed

- Producer API contract and data model specs (`specs/006-producer-app/`) updated to reflect comments resource and revised field names
- Producer README updated with comments API examples and updated k6 invocation

### Security

- No credentials, secrets, or PII present in committed files; `.env.example` contains only placeholder values and localhost defaults
