# Tasks: Kafka Performance Validation and Delivery Guarantee Testing

**Input**: `/specs/003-kafka-validation/spec.md`
**Prerequisites**: Feature 002 (Debezium CDC Setup) must be complete
**Tests**: Integration tests for performance and delivery guarantees

## Phase 1: Setup and Prerequisites

- [ ] T001 Verify Feature 002 is complete (make status-cdc shows RUNNING, Kafka UI accessible on port 8081)
- [ ] T002 Create kafka/tests/performance/ directory for performance benchmarks
- [ ] T003 Create kafka/tests/delivery/ directory for delivery guarantee tests
- [ ] T004 Create kafka/tests/results/ directory for test outputs and metrics
- [ ] T005 Create kafka/tests/results/.gitignore (ignore raw metrics JSON files, keep reports)
- [ ] T006 [P] Install test dependencies (verify jq, bc available in Kafka container or host)

## Phase 2: Performance Benchmarks (User Story 1 - P1) 🎯 MVP

**Goal**: Validate Kafka handles CDC workloads efficiently (≥1000 msg/sec, <100ms p95 latency, <10s startup)

**Test**: Run performance benchmarks with CDC-like payloads, measure throughput/latency/resources

### Performance Test Scripts

- [ ] T007 Create kafka/tests/performance/run-throughput-test.sh (1000 msg/sec for 60s using kafka-producer-perf-test)
- [ ] T008 Create kafka/tests/performance/run-burst-test.sh (5000 msg/sec for 10s to test backpressure)
- [ ] T009 Create kafka/tests/performance/run-sustained-load-test.sh (500 msg/sec for 5 minutes to test stability)
- [ ] T010 Create kafka/tests/performance/run-snapshot-simulation.sh (replay 895K CDC events, measure completion time)
- [ ] T011 Create kafka/tests/performance/run-startup-test.sh (measure broker cold start and warm restart time)

### Metrics Collection

- [ ] T012 Create kafka/tests/performance/collect-metrics.sh (parse kafka-perf-test output, capture Docker stats)
- [ ] T013 [P] Create kafka/tests/performance/generate-cdc-payload.sh (generate realistic CDC envelope format test messages)

### Integration

- [ ] T014 Create kafka/tests/test-all-performance.sh (run all 5 performance benchmarks in sequence)
- [ ] T015 Test performance suite: run test-all-performance.sh, verify all benchmarks complete successfully
- [ ] T016 [US1] Validate throughput test meets SC-001 (≥1000 msg/sec, <100ms p95 latency)

**Checkpoint**: Performance benchmarks complete and passing

## Phase 3: Delivery Guarantee Tests (User Story 2 - P2)

**Goal**: Verify at-least-once delivery under failures (0% message loss, duplicates acceptable)

**Test**: Simulate failures (broker restart, consumer restart, network partition), verify no message loss

### Delivery Guarantee Test Scripts

- [ ] T017 Create kafka/tests/delivery/test-broker-restart.sh (produce 1000 msgs, restart broker mid-stream, verify count ≥1000)
- [ ] T018 Create kafka/tests/delivery/test-consumer-restart.sh (consume 1000 msgs, restart consumer mid-stream, verify no gaps)
- [ ] T019 Create kafka/tests/delivery/test-network-partition.sh (pause Kafka container 10s during production, verify no loss)
- [ ] T020 Create kafka/tests/delivery/test-debezium-offset-recovery.sh (restart Debezium connector, verify CDC resumes from offset)
- [ ] T021 Create kafka/tests/delivery/test-multiple-consumers.sh (run 2 consumer groups, verify both receive all messages)

### Integration

- [ ] T022 Create kafka/tests/test-all-delivery.sh (run all 5 delivery guarantee tests in sequence)
- [ ] T023 Test delivery suite: run test-all-delivery.sh, verify all tests pass with 0% message loss
- [ ] T024 [US2] Validate broker restart test meets SC-003 (0% message loss under broker restart)

**Checkpoint**: Delivery guarantee tests complete and passing

## Phase 4: Reporting and Documentation (User Story 3 - P3)

**Goal**: Document performance baselines and failure behaviors for future optimization

**Test**: Review generated reports for completeness, accuracy, and actionable recommendations

### Report Generation

- [ ] T025 Create kafka/tests/generate-reports.sh (parse metrics, generate markdown reports)
- [ ] T026 Create specs/003-kafka-validation/reports/performance-baseline.md template
- [ ] T027 Create specs/003-kafka-validation/reports/delivery-guarantees.md template
- [ ] T028 Run performance tests and generate performance-baseline.md report
- [ ] T029 Run delivery tests and generate delivery-guarantees.md report

### Documentation

- [ ] T030 Update kafka/README.md with "Performance Validation" section (how to run tests, interpret results)
- [ ] T031 [P] Create kafka/tests/results/README.md (explain test output structure, metrics interpretation)
- [ ] T032 [US3] Document performance tuning recommendations based on benchmark results in reports

**Checkpoint**: Reports generated and documentation complete

## Phase 5: Automation and Polish

**Goal**: Provide automated Makefile targets for running tests

### Makefile Targets

- [ ] T033 Add Makefile target test-kafka-performance (runs test-all-performance.sh)
- [ ] T034 Add Makefile target test-kafka-delivery (runs test-all-delivery.sh)
- [ ] T035 [P] Add Makefile target kafka-reports (runs generate-reports.sh)
- [ ] T036 Add Makefile target test-kafka (runs both performance and delivery suites)

### Validation

- [ ] T037 [P] Test all Makefile targets end-to-end on clean environment
- [ ] T038 Verify test repeatability: run test-kafka twice, confirm consistent results
- [ ] T039 Final validation: verify SC-001 through SC-008 success criteria met

**Checkpoint**: Feature complete, all tests automated and passing

---

## Summary

**Total Tasks**: 39
- Setup: 6
- Performance Benchmarks (US1 - P1): 10 tasks
- Delivery Guarantee Tests (US2 - P2): 8 tasks
- Reporting & Documentation (US3 - P3): 8 tasks
- Automation & Polish: 7 tasks

**Parallel**: 6 tasks marked [P]
**MVP**: 20 tasks (Setup + Performance Benchmarks + first delivery test)

**Note**: This feature validates the Kafka infrastructure deployed in Feature 002 (Debezium CDC Setup). It does NOT create or deploy new Kafka infrastructure - all tests run against the existing Kafka broker from Feature 002.

**Dependencies**:
- **Requires**: Feature 002 (Debezium CDC Setup) complete
- **Enables**: Feature 004 (Consumer Application) by validating Kafka performance meets requirements

**Success Criteria Mapping**:
- SC-001: T016 (throughput test)
- SC-002: T011 (startup test)
- SC-003: T024 (broker restart test)
- SC-004: T018 (consumer restart test)
- SC-005: T010 (snapshot simulation)
- SC-006: T028 (performance report)
- SC-007: T029 (delivery report)
- SC-008: T033-T036 (Makefile automation)
