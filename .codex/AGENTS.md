# Repository Guidelines

## Project Structure & Module Organization

The repository is specification-driven. Source and tests are planned but may be created as features land.

- `.specify/`: SpecKit constitution, templates, and scripts (governance and workflow)
- `specs/`: Per-feature specs, plans, tasks, research, and contracts
- `<component>/tests/`: Component-specific integration tests (e.g., `postgres/tests/`, `debezium/tests/`)
- `src/`: Application source code (consumer app in Go) when implemented
- `docker-compose.yml`: Local pipeline orchestration

## Build, Test, and Development Commands

This project uses SpecKit commands for planning and execution:

- `/speckit.specify "..."`: create a feature spec
- `/speckit.plan`: generate an implementation plan
- `/speckit.tasks`: create executable tasks
- `/speckit.implement`: implement tasks with validation

When the runtime stack is present, use `docker-compose up` to run the full CDC pipeline locally.

## Coding Style & Naming Conventions

- Language focus: Go for the consumer application.
- Indentation: default Go formatting (tabs) once code exists.
- Naming: feature branches follow `###-feature-name`; feature work lives in `specs/[###-feature-name]/`.
- Logging: structured JSON with correlation IDs (required by constitution).

## Testing Guidelines

- Integration testing is mandatory; end-to-end coverage from PostgreSQL write to OpenSearch read.
- Tests are co-located with components: `<component>/tests/` (e.g., `postgres/tests/`, `debezium/tests/`).
- Kafka schema validation and OpenSearch document structure checks are required before PR approval.

## Commit & Pull Request Guidelines

- Commit message conventions are not documented; use clear, imperative messages (e.g., "Add Kafka consumer retry logic").
- PRs should include: linked spec folder, integration test evidence, and Docker Compose compatibility notes.

## Security & Configuration

- All service config via environment variables.
- Secrets must not be committed; use Docker secrets or external secret managers.
