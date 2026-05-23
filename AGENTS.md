# Repository Guidelines

## Project Structure & Module Organization

This repository is a Docker-first CDC pipeline: PostgreSQL -> Debezium/Kafka -> Go consumer -> OpenSearch, with a Go producer API, k6 benchmark suite, and local ops console. Top-level components own their code, Dockerfiles, scripts, and tests: `postgres/`, `debezium/`, `kafka/`, `producer/`, `consumer/`, `opensearch/`, `benchmark/`, and `ops-console/`. Cross-feature planning artifacts live in `specs/`. OpenSearch mappings are in `opensearch/mappings/`; database schema is in `postgres/init/`.

## Build, Test, and Development Commands

- `make up` / `make down`: start or stop the Compose stack.
- `make start`: start PostgreSQL and load sample data.
- `make start-cdc`: start Kafka, Kafka UI, Debezium Connect, and register the connector.
- `make start-opensearch && make create-indices`: start OpenSearch and create required indices.
- `make start-producer`: run the producer API container.
- `make start-ops-console`: run the web console at `http://localhost:8090`.
- `cd producer && go test ./...`: run producer tests.
- `cd consumer && go test ./...`: run consumer tests.
- `make -C benchmark build && make -C benchmark run-sustained`: build and run the sustained-load benchmark.

## Coding Style & Naming Conventions

Go services follow standard `gofmt` formatting and the existing layout: `cmd/` for entry points, `internal/` for service internals, `pkg/` for shared models, and `tests/` for test packages. Keep component-specific scripts inside the owning directory and name validation scripts with clear verbs, for example `test-connector-registration.sh` or `check-index-stats.sh`. Specs use numeric feature folders such as `006-producer-app`.

## Testing Guidelines

Use unit tests for transformation, indexing, handler, and error-path logic. Use Docker Compose-backed integration tests for behavior that crosses PostgreSQL, Debezium, Kafka, producer, consumer, or OpenSearch boundaries. For performance-sensitive changes, attach benchmark output from `benchmark/reports/` and note the target rate, consumer count, and hardware limits.

## Commit & Pull Request Guidelines

Recent commits use short imperative summaries, sometimes with feature prefixes or PR numbers, for example `feat. add opensearch component (#6)` and `Add xk6 load-testing benchmark suite... (#10)`. PRs should identify the touched component, link the relevant `specs/` folder when applicable, list verification commands, and include runtime evidence for pipeline, Compose, schema, or benchmark changes.

## Security & Configuration Tips

Use environment variables and `.env` for local overrides; do not commit secrets. When changing schema or CDC contracts, update producer models, Debezium expectations, consumer transforms, OpenSearch mappings, tests, and benchmark payloads together.
