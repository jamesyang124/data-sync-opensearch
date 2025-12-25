# Tasks: PostgreSQL Datasource Setup with Sample Data

**Input**: Design documents from `/specs/001-postgres-datasource-setup/`
**Prerequisites**: plan.md, spec.md

**Tests**: Integration tests included per constitution Principle III (NON-NEGOTIABLE)

**Organization**: Tasks grouped by user story to enable independent implementation and testing

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Infrastructure configuration project:
- Docker Compose at repository root
- PostgreSQL configuration in `postgres/` directory
- Integration tests in `postgres/tests/`
- Python scripts for data loading

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and directory structure

- [X] T001 Create PostgreSQL directory structure (postgres/init/, postgres/scripts/, postgres/sample-data/, postgres/config/)
- [X] T002 Create integration test directory (postgres/tests/)
- [X] T003 [P] Add PostgreSQL environment variables to .env.example (POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB, POSTGRES_PORT)
- [X] T004 [P] Create postgres/requirements.txt with Python dependencies (datasets, pandas, psycopg2-binary)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Docker service and base configuration - MUST complete before user stories

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T005 Create Dockerfile in postgres/Dockerfile (custom PostgreSQL image with Python, install datasets/pandas/psycopg2, copy scripts)
- [X] T006 Update docker-compose.yml PostgreSQL service (build from Dockerfile, mount sample-data volume, CDC-ready config)
- [X] T007 [P] Create postgresql.conf overrides in postgres/config/postgresql.conf (WAL settings for Debezium CDC compatibility)
- [X] T008 Add Makefile target start (docker-compose up postgres with build, wait for ready)
- [X] T009 [P] Add Makefile target stop (docker-compose stop postgres)
- [X] T010 [P] Add Makefile target logs (docker logs postgres container with -f option)
- [X] T011 Create wait-for-postgres.sh helper script in postgres/scripts/wait-for-postgres.sh (poll until pg_isready succeeds)

**Checkpoint**: Foundation ready - PostgreSQL container can start, user story implementation can begin

---

## Phase 3: User Story 1 - Start Development Environment (Priority: P1) 🎯 MVP

**Goal**: Start PostgreSQL database with normalized sample data using single command

**Independent Test**: Run make start, verify database accessible, check 3 tables exist with 10-50K total rows, verify foreign key relationships

### Integration Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T012 [P] [US1] Create test-database-connectivity.sh in postgres/tests/test-database-connectivity.sh (verify pg_isready, psql connection works)
- [X] T013 [P] [US1] Create test-schema-validation.sh in postgres/tests/test-schema-validation.sh (verify 3 tables exist, check columns and types, validate foreign keys)
- [X] T014 [P] [US1] Create test-data-loading.sh in postgres/tests/test-data-loading.sh (verify row counts 10-50K range, check data relationships)

### Implementation for User Story 1

**Schema Creation**:

- [X] T015 [P] [US1] Create 01-create-schema.sql in postgres/init/01-create-schema.sql (CREATE TABLE videos, users, comments with primary keys, foreign keys, constraints)
- [X] T016 [P] [US1] Create 02-create-indexes.sql in postgres/init/02-create-indexes.sql (indexes on foreign keys, common query fields)

**Data Loading Scripts** (containerized):

- [X] T017 [US1] Create download-dataset.py in postgres/scripts/download-dataset.py (runs in container, downloads to /var/lib/postgresql/sample-data, selects 30K subset)
- [X] T018 [US1] Create normalize-data.py in postgres/scripts/normalize-data.py (runs in container, transforms to 3 tables with FKs, saves to mounted volume)
- [X] T019 [US1] Create load-data.sh in postgres/scripts/load-data.sh (orchestrates container-based download/normalize, uses psql COPY from mounted volume)
- [X] T020 [US1] Update Dockerfile to copy scripts into container image at build time
- [X] T021 [US1] Update Makefile start target to call load-data.sh if database is empty

**Health Check**:

- [X] T022 [US1] Add Makefile target health (psql query for database status, connection count, table row counts)

**Testing**:

- [X] T023 [US1] Test database startup: run make start, verify PostgreSQL builds and runs with Python environment
- [X] T024 [US1] Test schema creation: run make health, verify 3 tables with correct structure
- [X] T025 [US1] Test data loading: verify containerized scripts execute, 30K rows loaded, foreign key integrity maintained
- [X] T026 [US1] Run integration tests for US1: all 3 test scripts (connectivity, schema, data loading)

**Checkpoint**: PostgreSQL running with normalized YouTube comment data ready for Debezium CDC

---

## Phase 4: User Story 2 - Reset Database State (Priority: P2)

**Goal**: Reset database to initial state with fresh sample data for testing

**Independent Test**: Modify database (add/update/delete rows), run make reset, verify database restored to original state with correct row counts

### Integration Tests for User Story 2

- [X] T027 [US2] Create test-makefile-commands.sh in postgres/tests/test-makefile-commands.sh (test reset command, verify data restored)

### Implementation for User Story 2

- [X] T028 [US2] Create reset-database.sh in postgres/scripts/reset-database.sh (drop database, recreate, re-run init scripts, reload data via container)
- [X] T029 [US2] Add Makefile target reset (calls reset-database.sh with confirmation prompt)
- [X] T030 [US2] Update reset script to show before/after row counts
- [X] T031 [US2] Test reset: modify data, run make reset, verify restoration to original state
- [X] T032 [US2] Run integration test for US2: test-makefile-commands.sh

**Checkpoint**: Reset functionality working - developers can restore clean state anytime

---

## Phase 5: User Story 3 - Inspect Sample Data (Priority: P3)

**Goal**: Provide commands to view schema and sample data for understanding data model

**Independent Test**: Run make inspect-schema and make inspect-data, verify output shows table definitions and sample rows

### Implementation for User Story 3

- [X] T033 [P] [US3] Create inspect-schema.sh in postgres/scripts/inspect-schema.sh (psql \\d commands to show table structure, foreign keys, indexes)
- [X] T034 [P] [US3] Create inspect-data.sh in postgres/scripts/inspect-data.sh (SELECT first 10 rows from each table with formatted output)
- [X] T035 [US3] Add Makefile target inspect-schema (calls inspect-schema.sh)
- [X] T036 [P] [US3] Add Makefile target inspect-data (calls inspect-data.sh)
- [X] T037 [US3] Test inspection commands: verify schema and data output readable and accurate
- [X] T038 [US3] Update test-makefile-commands.sh to include inspect commands validation

**Checkpoint**: All user stories complete - full PostgreSQL development environment ready

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, validation, and production readiness

- [X] T039 [P] Create README.md in postgres/ directory documenting Dockerfile, directory structure, scripts, schema design
- [X] T040 [P] Add inline documentation to all SQL and Python scripts
- [X] T041 Create quickstart.md documenting Docker build, setup steps, Makefile commands, troubleshooting
- [X] T042 [P] Add error handling to all shell scripts (set -e, check command exits, helpful error messages)
- [X] T043 [P] Add data validation to normalize-data.py (check required columns exist, handle missing values)
- [X] T044 Create test-all.sh in postgres/tests/test-all.sh (runs all integration tests, reports summary)
- [X] T045 Verify all Makefile targets work end-to-end (requires docker build + run)
- [X] T046 [P] Update main README.md with PostgreSQL setup instructions (Docker-first approach)
- [X] T047 [P] Add .gitignore entries for postgres/sample-data/ cached files
- [X] T048 Final validation: clean environment, docker compose build, make start, verify all tests pass

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational
  - **US1 (P1)**: Can start after Foundational
  - **US2 (P2)**: Depends on US1 (needs database and data to reset)
  - **US3 (P3)**: Depends on US1 (needs schema and data to inspect)
- **Polish (Phase 6)**: Depends on all user stories

### User Story Dependencies

- **US1 (P1)**: Independent after Foundational - creates database and loads data
- **US2 (P2)**: Depends on US1 - resets what US1 created
- **US3 (P3)**: Depends on US1 - inspects what US1 created

### Parallel Opportunities

**Phase 1**: All 4 tasks parallel (T001-T004 - different files/directories)

**Phase 2**: Some parallel:
- T006, T008-T009 (different files)

**Phase 3 (US1)**:
- Tests T011-T013 (different test files)
- Schema T014-T015 (different SQL files)

**Phase 5 (US3)**:
- T032-T033 (different scripts)
- T034-T035 (different Makefile targets)

**Phase 6**: Most tasks parallel (T038-T039, T041-T042, T045-T046 - different files)

---

## Parallel Example: User Story 1

```bash
# Launch all integration tests together (write first, ensure FAIL):
Task: "Create test-database-connectivity.sh in postgres/tests/test-database-connectivity.sh"
Task: "Create test-schema-validation.sh in postgres/tests/test-schema-validation.sh"
Task: "Create test-data-loading.sh in postgres/tests/test-data-loading.sh"

# Launch schema creation SQL files together:
Task: "Create 01-create-schema.sql in postgres/init/01-create-schema.sql"
Task: "Create 02-create-indexes.sql in postgres/init/02-create-indexes.sql"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T004)
2. Complete Phase 2: Foundational (T005-T010)
3. Complete Phase 3: User Story 1 (T011-T025)
4. **VALIDATE**: PostgreSQL running with sample data, all tests passing

**MVP Scope**: 25 tasks = PostgreSQL datasource ready for Debezium CDC (feature 002)

### Incremental Delivery

1. **Setup + Foundational** (T001-T010) → PostgreSQL deployable
2. **+ User Story 1** (T011-T025) → Database with sample data ✅ **MVP**
3. **+ User Story 2** (T026-T031) → Reset capability added
4. **+ User Story 3** (T032-T037) → Inspection commands added
5. **+ Polish** (T038-T047) → Documentation complete

---

## Task Summary

**Total Tasks**: 48

**Breakdown by Phase**:
- Phase 1 (Setup): 4 tasks
- Phase 2 (Foundational): 7 tasks (includes Dockerfile creation)
- Phase 3 (User Story 1): 15 tasks (containerized data loading)
- Phase 4 (User Story 2): 6 tasks
- Phase 5 (User Story 3): 6 tasks
- Phase 6 (Polish): 10 tasks

**Breakdown by User Story**:
- User Story 1 (P1): 15 tasks - Start environment with data
- User Story 2 (P2): 6 tasks - Reset database state
- User Story 3 (P3): 6 tasks - Inspect data

**Parallel Opportunities**: 19 tasks marked [P]

**Independent Test Criteria**:
- **US1**: Connect to database, verify 3 tables, 10-50K rows, foreign keys working
- **US2**: Modify database, reset, verify restoration to original state
- **US3**: Run inspect commands, verify schema and data displayed correctly

**MVP Scope**: 26 tasks (Setup + Foundational + US1)
**Docker-First**: Custom PostgreSQL image with Python, all data operations containerized

---

## Notes

- All tasks follow format with checkbox, ID, [P] marker, [Story] label, file path
- Integration tests mandatory per constitution
- Tests written FIRST before implementation
- Dataset normalized from flat CSV to proper relational structure
- WAL settings configured for Debezium CDC compatibility (feature 002 dependency)
