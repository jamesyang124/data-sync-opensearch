# Tasks: Debezium CDC Configuration

**Input**: `/specs/002-debezium-config/spec.md`
**Tests**: Integration tests included per constitution

## Phase 1: Setup

- [ ] T001 Create Debezium directory structure (debezium/connectors/, debezium/scripts/, debezium/config/)
- [ ] T002 Create integration test directory (tests/integration/debezium/)

## Phase 2: Foundational

- [ ] T003 Add Debezium Connect service to docker-compose.yml (image: debezium/connect:2.5, depends on Kafka and PostgreSQL)
- [ ] T004 [P] Add Kafka Connect UI service to docker-compose.yml (image: landoop/kafka-connect-ui or debezium/debezium-ui)
- [ ] T005 Create connect-standalone.properties in debezium/config/ (bootstrap servers, offset storage, converter settings)
- [ ] T006 Add Makefile target start-cdc (docker-compose up debezium services)
- [ ] T007 [P] Add Makefile target stop-cdc (stop Debezium services)

## Phase 3: User Story 1 - Configure PostgreSQL CDC Connector (P1) 🎯 MVP

**Goal**: Capture CDC events from PostgreSQL and publish to Kafka topics

**Test**: Insert/update/delete in PostgreSQL, verify events in Kafka topics

### Integration Tests

- [ ] T008 [P] [US1] Create test-connector-registration.sh (verify connector registered via REST API)
- [ ] T009 [P] [US1] Create test-cdc-capture.sh (insert row, verify event in Kafka topic)
- [ ] T010 [P] [US1] Create test-offset-recovery.sh (restart connector, verify resumes from offset)

### Implementation

- [ ] T011 [US1] Create postgres-connector.json in debezium/connectors/ (connector.class, database.hostname, table.include.list for 3 tables, topic routing)
- [ ] T012 [US1] Create register-connector.sh in debezium/scripts/ (POST connector config to :8083/connectors)
- [ ] T013 [US1] Update start-cdc target to auto-register connector
- [ ] T014 [US1] Test CDC: insert test row in PostgreSQL, consume from Kafka topic, verify event structure
- [ ] T015 [US1] Run integration tests for US1

**Checkpoint**: CDC events flowing from PostgreSQL to Kafka

## Phase 4: User Story 2 - Monitor CDC Health (P2)

**Goal**: Monitor connector health and performance via web UI

**Test**: Access UI, verify connector status visible, check lag metrics

### Implementation

- [ ] T016 [US2] Create check-connector-status.sh in debezium/scripts/ (GET :8083/connectors/postgres-connector/status with jq formatting)
- [ ] T017 [P] [US2] Add Makefile target status-cdc (calls check-connector-status.sh)
- [ ] T018 [US2] Document web UI access in README (URL, features, how to check lag)
- [ ] T019 [US2] Test monitoring: access UI, verify connector visible, check status endpoint

**Checkpoint**: Monitoring working via UI and CLI

## Phase 5: User Story 3 - Manage Connector Lifecycle (P3)

**Goal**: Start, stop, restart connector without data loss

**Test**: Restart connector, verify offset preserved, no duplicate events

### Implementation

- [ ] T020 [US3] Create delete-connector.sh in debezium/scripts/ (DELETE connector via REST API)
- [ ] T021 [P] [US3] Create restart-connector.sh (delete + re-register)
- [ ] T022 [P] [US3] Add Makefile target restart-cdc (calls restart-connector.sh)
- [ ] T023 [US3] Test lifecycle: restart connector, verify offset preserved, no event loss/duplication

**Checkpoint**: Full connector lifecycle management working

## Phase 6: Polish

- [ ] T024 [P] Create README in debezium/ directory
- [ ] T025 [P] Add error handling to all scripts
- [ ] T026 Create quickstart.md documenting connector setup
- [ ] T027 Final validation: clean state, register connector, verify CDC working

---

## Summary

**Total Tasks**: 27
- Setup: 2
- Foundational: 5  
- US1 (P1): 8 tasks - CDC configuration
- US2 (P2): 4 tasks - Monitoring
- US3 (P3): 4 tasks - Lifecycle management
- Polish: 4

**Parallel**: 9 tasks marked [P]
**MVP**: 15 tasks (Setup + Foundational + US1)

**Dependencies**:
- Requires Feature 001 (PostgreSQL) and Feature 003 (Kafka) running
- US2 and US3 depend on US1
