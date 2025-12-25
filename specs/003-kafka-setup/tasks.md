# Tasks: Kafka Broker Configuration with Delivery Guarantees

**Input**: `/specs/003-kafka-setup/spec.md`
**Tests**: Integration tests included

## Phase 1: Setup

- [X] T001 Create Kafka directory structure (kafka/scripts/, kafka/tests/)
- [X] T002 Create integration test directory (kafka/tests/)

## Phase 2: Foundational

- [X] T003 Add Kafka broker service to docker-compose.yml (KRaft mode, image: confluentinc/cp-kafka:7.6, at-least-once config)
- [X] T004 [P] Add Kafka UI service (AKHQ or Kafka UI) to docker-compose.yml
- [X] T005 Document broker settings in kafka/README.md (acks=all, retries=max, min.insync.replicas=1, log retention)
- [X] T006 Add Makefile target start-kafka (docker-compose up kafka services)
- [X] T007 [P] Add Makefile target stop-kafka (stop Kafka)

## Phase 3: User Story 1 - Deploy Kafka with Delivery Semantics (P1) 🎯 MVP

**Goal**: Kafka broker running with at-least-once delivery configuration

**Test**: Start Kafka, verify broker accessible, check configuration settings

### Integration Tests

- [X] T009 [P] [US1] Create test-broker-health.sh in kafka/tests/ (verify broker running, controller health)
- [X] T010 [P] [US1] Create test-topic-creation.sh in kafka/tests/ (create test topic, verify exists)

### Implementation

- [X] T011 [US1] Create create-topics.sh in kafka/scripts/ (kafka-topics create for 3 CDC topics: dbserver.public.videos, users, comments)
- [X] T012 [US1] Add Makefile target create-topics (calls create-topics.sh)
- [X] T013 [US1] Test broker: verify startup, check logs, test topic creation
- [X] T014 [US1] Run integration tests for US1

**Checkpoint**: Kafka broker running with CDC topics ready

## Phase 4: User Story 2 - Verify Delivery Guarantees (P2)

**Goal**: Validate at-least-once delivery under failure scenarios

**Test**: Produce messages, simulate failures, verify no loss (may have duplicates)

### Integration Tests

- [X] T015 [US2] Create test-delivery-guarantees.sh in kafka/tests/ (produce messages, restart broker, verify all received)

### Implementation

- [X] T016 [US2] Create test-producer.sh in kafka/tests/ (produce test messages with acks=all)
- [X] T017 [US2] Create test-consumer.sh in kafka/tests/ (consume and count messages)
- [X] T018 [US2] Test delivery: produce, restart broker, consume, verify count
- [X] T019 [US2] Run integration test for US2

**Checkpoint**: Delivery guarantees validated

## Phase 5: User Story 3 - Monitor Kafka Performance (P3)

**Goal**: Monitor broker health, topic metrics, consumer lag

**Test**: Access monitoring UI, verify broker visible, check topic statistics

### Implementation

- [X] T020 [US3] Create check-topics.sh in kafka/scripts/ (kafka-topics --list and --describe)
- [X] T021 [P] [US3] Add Makefile target status-kafka (broker health + topic list)
- [X] T022 [US3] Document monitoring UI access in README
- [X] T023 [US3] Test monitoring: access UI, verify broker metrics visible

**Checkpoint**: Monitoring working

## Phase 6: Polish

- [X] T024 [P] Create README in kafka/ directory
- [X] T025 [P] Add error handling to scripts
- [X] T026 Create quickstart.md for Kafka setup
- [X] T027 Final validation: clean state, start Kafka, create topics, test delivery

---

## Summary

**Total Tasks**: 27
- Setup: 2
- Foundational: 6
- US1 (P1): 6 tasks - Broker deployment
- US2 (P2): 5 tasks - Delivery guarantees
- US3 (P3): 4 tasks - Monitoring
- Polish: 4

**Parallel**: 8 tasks marked [P]
**MVP**: 14 tasks (Setup + Foundational + US1)

**Note**: Feature 001 (PostgreSQL) and 002 (Debezium) depend on this Kafka broker being available
