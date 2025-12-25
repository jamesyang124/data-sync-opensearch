# Implementation Plan: PostgreSQL Datasource Setup with Sample Data

**Branch**: `001-postgres-datasource-setup` | **Date**: 2025-12-25 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-postgres-datasource-setup/spec.md`

## Summary

Deploy PostgreSQL database with Docker Compose, automatically load 500K subset from Hugging Face youtube-comment-sentiment dataset, normalize into 3-table schema (videos, users, comments), and provide Makefile targets for lifecycle management (start, stop, reset, health, inspect-schema, inspect-data, logs).

**Technical Approach**: Docker Compose with PostgreSQL 14+, Python script to download and normalize Hugging Face dataset, SQL schema with foreign keys, volume persistence, and Makefile automation for developer workflow.

## Technical Context

**Language/Version**: Python 3.10+ for data loading scripts, SQL for schema, Bash for Makefile targets, Docker Compose YAML
**Primary Dependencies**: PostgreSQL 14+ (Docker image), Python libraries (datasets, pandas, psycopg2), Hugging Face datasets library
**Storage**: Docker named volume for PostgreSQL data persistence, local CSV cache for dataset download
**Testing**: Integration tests validating database connectivity, schema creation, data loading, and Makefile commands
**Target Platform**: Docker Desktop (macOS/Linux/Windows) for local development
**Project Type**: Infrastructure configuration (database + scripts)
**Performance Goals**: Database startup <30 seconds, sample data loading 500K records in <10 minutes, Makefile commands respond within 5 seconds
**Constraints**: Single PostgreSQL instance (not clustered), local development only, subset of full dataset for faster setup
**Scale/Scope**: 3 tables, 500K total records, 7 Makefile targets, normalized schema with foreign keys

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle I: Plugin Architecture ✅ PASS

**Status**: Not directly applicable - This is datasource infrastructure, the first component in the pipeline.

**Evaluation**: PostgreSQL datasource is the foundation of the CDC pipeline. The schema design (3 normalized tables) provides a clean contract for downstream components (Debezium, Kafka, Consumer, OpenSearch). Schema is defined via SQL migrations, enabling future evolution.

**No violations**.

### Principle II: Event-Driven Integration ✅ PASS

**Status**: Compliant - PostgreSQL serves as event source for CDC pipeline.

**Evaluation**: PostgreSQL acts as the data source in the event-driven pipeline (**PostgreSQL** → Debezium → Kafka → Consumer → OpenSearch). Write-ahead log (WAL) will be captured by Debezium (feature 002) to generate change events. This feature establishes the source of truth for the pipeline.

**No violations**.

### Principle III: Integration Testing (NON-NEGOTIABLE) ✅ PASS

**Status**: Compliant - Integration tests required for database infrastructure.

**Evaluation**: Feature includes integration test requirements:
- **Database connectivity test**: Verify PostgreSQL container starts and accepts connections
- **Schema validation test**: Verify 3 tables created with correct columns, types, and foreign keys
- **Data loading test**: Verify sample data loaded, row counts match expected range (500K)
- **Makefile command test**: Verify all 7 targets execute successfully

**Required Test Coverage** (per constitution):
- ✅ Schema changes: Test foreign key constraints, indexes created
- ✅ Data integrity: Validate normalized data relationships (videos → comments, users → comments)
- ✅ Error scenarios: Test port conflicts, missing .env, Docker not running

**No violations**.

### Principle IV: Observability & Debugging ✅ PASS

**Status**: Compliant - PostgreSQL provides query logging and connection monitoring.

**Evaluation**:
- **Structured logs**: PostgreSQL logs SQL statements to stdout (configurable log level)
- **Health checks**: Makefile target `make health` checks database connectivity and provides row counts
- **Inspection commands**: `make inspect-schema` and `make inspect-data` provide schema and sample data visibility
- **Container logs**: `make logs` exposes PostgreSQL container logs for debugging
- **SQL visibility**: PostgreSQL log_statement setting can log all queries for Debezium CDC debugging

**No violations**.

### Principle V: Docker-First Deployment ✅ PASS

**Status**: Compliant - All deployment via Docker Compose.

**Evaluation**:
- **Docker Compose**: PostgreSQL deployed as container in `docker-compose.yml`
- **Volume persistence**: Named volume for `/var/lib/postgresql/data`
- **Environment variables**: Credentials and ports configurable via .env file
- **Single command startup**: `make start` or `docker-compose up` brings up database
- **No manual setup**: Data loading automated via init scripts or Python scripts executed in container

**No violations**.

### Technology Constraints ✅ PASS

**Evaluation**:
- **Data Capture**: PostgreSQL as CDC source ✅ (feeds into Debezium feature 002)
- **Container Orchestration**: Docker Compose ✅ (docker-compose.yml with PostgreSQL service)
- **Other constraints**: Not applicable to datasource

**No violations**.

### Constitution Check Summary

**Status**: ✅ **ALL GATES PASSED** - Ready for Phase 0 research.

All five core principles satisfied. Feature establishes PostgreSQL datasource foundation using Docker Compose, provides data for event-driven CDC pipeline, includes integration test structure, exposes observability via Makefile commands, and maintains Docker-first deployment.

## Project Structure

### Documentation (this feature)

```text
specs/001-postgres-datasource-setup/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
# Infrastructure configuration structure
docker-compose.yml           # PostgreSQL service with custom build

postgres/
├── Dockerfile                    # Multi-stage build (python-builder + postgres final)
├── requirements.txt              # Python dependencies (datasets, pandas, psycopg2)
├── init/
│   ├── 01-create-schema.sql      # Create tables with foreign keys
│   └── 02-create-indexes.sql     # Create indexes for performance
├── scripts/
│   ├── download-dataset.py       # Download Hugging Face dataset (runs in container)
│   ├── normalize-data.py         # Transform to 3-table structure (runs in container)
│   └── load-data.sh              # Orchestrate download + normalize + load
├── sample-data/
│   └── .gitkeep                  # Cache directory for dataset files (mounted volume)
└── config/
    └── postgresql.conf           # PostgreSQL configuration overrides

tests/integration/
└── postgres/
    ├── test-database-connectivity.sh   # Verify connection
    ├── test-schema-validation.sh       # Verify tables and constraints
    ├── test-data-loading.sh            # Verify row counts and relationships
    └── test-makefile-commands.sh       # Verify all Makefile targets

Makefile                    # Add PostgreSQL targets
.env.example                # Add PostgreSQL credentials
```

**Structure Decision**: Multi-stage Docker build with PostgreSQL and Python runtime. Stage 1 compiles Python dependencies (datasets, pandas, psycopg2). Stage 2 creates final PostgreSQL image with runtime-only Python (no build tools). Dataset downloads at runtime (first container start) and caches in mounted volume. Data loading scripts run inside container for true Docker-first deployment. SQL init scripts create schema on first database startup. Makefile provides developer-friendly commands. This multi-stage approach reduces final image size, avoids build memory issues, and eliminates host Python dependency requirements.

## Complexity Tracking

**No constitutional violations** - No entries required.

All constitutional principles satisfied without exceptions.
