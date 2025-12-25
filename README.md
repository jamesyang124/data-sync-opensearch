# Data Sync OpenSearch

PostgreSQL to OpenSearch data synchronization using CDC (Change Data Capture) with Debezium, Kafka, and a consumer application.

## Architecture Overview

```
PostgreSQL → Debezium (CDC) → Kafka → Consumer App (Go) → OpenSearch
```

- **Change Data Capture**: Debezium captures database changes from PostgreSQL
- **Event Streaming**: Kafka handles event distribution and replay capability
- **Consumer Application**: Golang application processes events and syncs to OpenSearch
- **Plugin System**: Extensible architecture for custom data sources and transformations

## Getting Started

### Prerequisites

- Docker and Docker Compose
- AI agent with SpecKit commands (Claude Code, etc.)

Initialize SpecKit commands for this repo:

```bash
export CODEX_CONFIG_DIR="$HOME/.codex"
export CODEX_HOME=$(pwd)/.codex
uvx --from git+https://github.com/github/spec-kit.git specify init --ai codex --here
```

### Development Workflow

This project follows a structured specification-driven development workflow using SpecKit commands. The workflow ensures proper planning, design, and implementation with built-in quality gates.

## SpecKit Workflow

### Core Workflow (Required)

Follow these steps in order to develop features:

#### 1. Establish Project Principles

```bash
/speckit.constitution
```

Define or update the project's core principles, technology constraints, and governance rules. This step establishes the foundation for all development decisions.

**Status**: ✅ Completed (v1.0.1)

#### 2. Create Feature Specification

```bash
/speckit.specify "Feature description here"
```

Create a detailed specification for your feature including:
- User stories with priorities (P1, P2, P3)
- Functional requirements
- Acceptance criteria
- Success metrics

**Output**: `/specs/[###-feature-name]/spec.md`

#### 3. Create Implementation Plan

```bash
/speckit.plan
```

Generate a comprehensive implementation plan with:
- Technical context and dependencies
- Constitution compliance check
- Project structure
- Research findings
- Data models and API contracts

**Output**: `/specs/[###-feature-name]/plan.md`, `research.md`, `data-model.md`, `contracts/`

#### 4. Generate Actionable Tasks

```bash
/speckit.tasks
```

Convert the implementation plan into dependency-ordered, executable tasks organized by user story for independent implementation and testing.

**Output**: `/specs/[###-feature-name]/tasks.md`

#### 5. Execute Implementation

```bash
/speckit.implement
```

Execute all tasks from `tasks.md`, implementing features according to the plan with proper testing and validation at each checkpoint.

### Enhancement Commands (Optional)

These commands improve quality and reduce risk but are not required:

#### Clarify Ambiguities (Before Planning)

```bash
/speckit.clarify
```

**When to use**: After `/speckit.specify`, before `/speckit.plan`

Identifies underspecified areas in the feature specification by asking targeted clarification questions. Use this to de-risk ambiguous requirements before investing in detailed planning.

#### Validate Consistency (Before Implementation)

```bash
/speckit.analyze
```

**When to use**: After `/speckit.tasks`, before `/speckit.implement`

Performs cross-artifact consistency analysis across `spec.md`, `plan.md`, and `tasks.md` to catch misalignments, gaps, or inconsistencies.

#### Generate Quality Checklist (After Planning)

```bash
/speckit.checklist
```

**When to use**: After `/speckit.plan`

Generates custom quality checklists to validate requirements completeness, clarity, and consistency based on the feature domain.

## Project Constitution

The project follows these core principles (see `.specify/memory/constitution.md` for full details):

1. **Plugin Architecture**: Standalone, pluggable components for extensibility
2. **Event-Driven Integration**: CDC events flow through Kafka with clear contracts
3. **Integration Testing (NON-NEGOTIABLE)**: TDD for integration tests, full pipeline coverage required
4. **Observability & Debugging**: Structured JSON logging, correlation IDs, health checks
5. **Docker-First Deployment**: All services via Docker Compose, `docker-compose up` for full pipeline

### Technology Stack

- **Data Capture**: Debezium PostgreSQL connector
- **Message Queue**: Apache Kafka with consumer groups
- **Search Engine**: OpenSearch
- **Consumer Application**: Golang (preferred)
- **Container Orchestration**: Docker Compose (local/test), Kubernetes-compatible for production

## Example Workflow

Here's a complete example of developing a new feature:

```bash
# 1. Create specification for syncing user table
/speckit.specify "Sync user table from PostgreSQL to OpenSearch with real-time updates"

# 2. (Optional) Clarify any ambiguous requirements
/speckit.clarify

# 3. Generate implementation plan
/speckit.plan

# 4. (Optional) Generate validation checklist
/speckit.checklist

# 5. Generate actionable tasks
/speckit.tasks

# 6. (Optional) Validate consistency before implementation
/speckit.analyze

# 7. Execute implementation
/speckit.implement
```

## Project Structure

```
data-sync-opensearch/
├── .specify/
│   ├── memory/
│   │   └── constitution.md          # Project governance and principles
│   ├── templates/                   # Templates for specs, plans, tasks
│   └── scripts/                     # Automation scripts
├── specs/
│   └── [###-feature-name]/          # Feature-specific documentation
│       ├── spec.md                  # Feature specification
│       ├── plan.md                  # Implementation plan
│       ├── tasks.md                 # Actionable task list
│       ├── research.md              # Research findings
│       ├── data-model.md            # Data models
│       └── contracts/               # API contracts
├── postgres/                        # PostgreSQL datasource
│   ├── tests/                       # PostgreSQL integration tests
│   └── ...
├── debezium/                        # Debezium CDC configuration
│   ├── tests/                       # Debezium integration tests
│   └── ...
├── src/                             # Source code (to be created)
└── docker-compose.yml               # Service orchestration
```

## Development Guidelines

### Branch Strategy

Feature branches follow the pattern: `###-feature-name`

All feature work is tracked in `/specs/[###-feature-name]/` directory.

### Integration Testing Requirements

- Integration tests MUST pass before PR approval
- Kafka message schema validation required
- OpenSearch document structure verified
- End-to-end pipeline test (PostgreSQL write → OpenSearch read) required

### Code Review Checklist

- [ ] Plugin follows extension contract
- [ ] Structured logging with correlation IDs implemented
- [ ] Docker Compose service definition included
- [ ] Integration test coverage validated
- [ ] Constitution principles compliance verified

## Quick Start

### PostgreSQL Datasource Setup (Feature 001)

Get started with the PostgreSQL database and sample data:

```bash
# Start PostgreSQL with sample data
make start

# Verify setup
make health

# View schema and sample data
make inspect-schema
make inspect-data
```

**What gets loaded**:
- 500K YouTube comments from Hugging Face dataset
- Normalized into 3 tables: videos, users, comments
- CDC-ready with WAL enabled for Debezium
- Database is ephemeral; data resets on container restart

**Available commands**:
- `make start` - Start PostgreSQL and load sample data
- `make load-data` - Load CSVs into PostgreSQL
- `make stop` - Stop PostgreSQL
- `make reset` - Reset database to clean state
- `make health` - Check database status
- `make inspect-schema` - View table structures
- `make inspect-data` - View sample records

See [postgres/quickstart.md](postgres/quickstart.md) for detailed setup guide.

### Debezium CDC Configuration (Feature 002)

Configure Change Data Capture to stream PostgreSQL changes to Kafka:

```bash
# Start CDC services (Kafka, Kafka UI, Debezium Connect)
make start-cdc

# Check connector status
make status-cdc

# Restart connector
make restart-cdc

# Stop CDC services
make stop-cdc
```

**What gets configured**:
- Kafka broker with KRaft mode (Confluent Platform 7.6.0)
- Debezium Connect 2.5 with PostgreSQL connector
- Kafka UI for monitoring and topic visualization
- CDC topics: `dbserver.public.videos`, `dbserver.public.users`, `dbserver.public.comments`
- Automatic connector registration on startup

**Web Interfaces**:
- **Kafka UI**: http://localhost:8081 - Monitor topics, consumers, and CDC events
- **Kafka Connect API**: http://localhost:8083 - REST API for connector management

**Integration Tests**:
```bash
# Test connector registration
bash debezium/tests/test-connector-registration.sh

# Test CDC event capture
bash debezium/tests/test-cdc-capture.sh

# Test offset recovery
bash debezium/tests/test-offset-recovery.sh
```

**Key Features**:
- Real-time CDC: Changes captured within seconds
- Initial snapshot: 895K records (videos + users + comments)
- ARM64 compatible: Works on Apple Silicon
- Offset management: No data loss on restart
- Event format: Debezium envelope with full CDC metadata (before/after, op, source)

**Available commands**:
- `make start-cdc` - Start Kafka, Connect, UI, and register connector
- `make stop-cdc` - Stop CDC services
- `make restart-cdc` - Restart connector (delete + re-register)
- `make status-cdc` - Check connector health
- `make register-connector` - Manually register connector

See [debezium/README.md](debezium/README.md) for detailed CDC documentation and [specs/002-cdc-setup/quickstart.md](specs/002-cdc-setup/quickstart.md) for setup guide.

## Configuration Management

All service configuration via environment variables. Secrets managed through Docker secrets or external secret management (never committed to repository).

## Contributing

1. Review the constitution (`.specify/memory/constitution.md`)
2. Follow the SpecKit workflow for all features
3. Ensure integration tests pass
4. Verify Docker Compose compatibility
5. Include correlation IDs in all logs

## License

[Specify your license here]

## Support

For issues or questions about the SpecKit workflow, refer to the command documentation in `.claude/commands/` or `.specify/templates/`.
