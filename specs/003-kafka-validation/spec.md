# Feature Specification: Kafka Performance Validation and Delivery Guarantee Testing

**Feature Branch**: `003-kafka-validation`
**Created**: 2025-12-25
**Status**: Draft
**Input**: User description: "kafka configs, especially for delivery mode choice"
**Prerequisites**: Feature 002 (Debezium CDC Setup) must be complete

## Overview

This feature **validates and tests** the Kafka infrastructure deployed in Feature 002 (Debezium CDC Setup). It focuses on performance benchmarking under CDC workloads and delivery guarantee validation under failure scenarios.

**What Feature 002 Already Provides:**
- Kafka broker (Confluent Platform 7.6.0) in KRaft mode
- CDC topics: dbserver.public.{videos,users,comments}
- Kafka UI monitoring (port 8081)
- At-least-once delivery configuration
- Debezium connector producing CDC events
- Envelope format for full CDC metadata

**What This Feature Adds:**
- Performance validation (1000 msg/sec throughput, <10s startup)
- Delivery guarantee testing under broker failures
- Load testing with CDC workload (895K snapshot + streaming)
- Integration tests for at-least-once semantics
- Performance benchmarking reports

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Validate Kafka Performance Under CDC Load (Priority: P1)

As a developer, I need to validate that the Kafka broker handles CDC workloads efficiently, so I can ensure the data sync pipeline meets throughput and latency requirements for the OpenSearch use case.

**Why this priority**: Performance validation is essential before building the consumer application (Feature 004+). If Kafka can't handle the load, we need to tune configuration before proceeding.

**Independent Test**: Can be fully tested by running performance benchmarks with CDC event payloads, measuring throughput, latency, and resource usage under various load conditions.

**Acceptance Scenarios**:

1. **Given** Kafka broker is running with CDC topics, **When** performance benchmark produces 1000 messages per second for 60 seconds, **Then** Kafka accepts all messages with <100ms average latency and no message loss
2. **Given** Kafka broker is stopped, **When** developer starts Kafka and measures startup time, **Then** broker becomes ready to accept connections in <10 seconds
3. **Given** Debezium snapshot is running (895K records), **When** developer monitors Kafka broker metrics, **Then** memory usage stays <2GB and CPU usage <80% during snapshot load

---

### User Story 2 - Test At-Least-Once Delivery Guarantees Under Failures (Priority: P2)

As a developer, I need to verify that Kafka maintains at-least-once delivery guarantees even during broker failures or network issues, so I can trust the pipeline won't lose critical CDC events.

**Why this priority**: Delivery guarantees only matter if they hold during failures. This validates the at-least-once configuration from Feature 002 under realistic failure scenarios.

**Independent Test**: Can be tested by simulating broker restart, network partition, or producer failure and verifying no message loss occurs (duplicates are acceptable).

**Acceptance Scenarios**:

1. **Given** Kafka is running with at-least-once config, **When** test producer sends 1000 messages and broker restarts mid-stream, **Then** consumer receives all 1000 messages (possibly with duplicates) after broker recovers
2. **Given** Kafka is running with test consumer consuming messages, **When** broker restarts and consumer reconnects, **Then** consumer resumes from last committed offset with no message loss
3. **Given** Debezium is producing CDC events, **When** Kafka broker restarts during database changes, **Then** all database changes appear in Kafka topics after recovery (no CDC events lost)

---

### User Story 3 - Document Performance Baselines and Failure Behaviors (Priority: P3)

As a developer, I need documented performance baselines and failure recovery behaviors, so I can debug issues and optimize the pipeline in the future.

**Why this priority**: Important for operational knowledge but not required for functional validation.

**Independent Test**: Can be tested by reviewing generated documentation for completeness, accuracy, and actionable recommendations.

**Acceptance Scenarios**:

1. **Given** performance tests are complete, **When** developer reviews performance report, **Then** report shows throughput (msg/sec), latency percentiles (p50, p95, p99), and resource usage (CPU, memory, disk)
2. **Given** delivery guarantee tests are complete, **When** developer reviews failure test report, **Then** report documents message loss (should be 0), duplicate rate, and recovery time for each failure scenario
3. **Given** all tests are complete, **When** developer reviews recommendations, **Then** documentation provides tuning suggestions based on test results

---

### Edge Cases

- What happens when Kafka runs out of disk space during high-volume CDC? Broker should stop accepting new messages and log clear error; producers should receive error and can retry after space is freed (validate this behavior).
- How does Kafka handle very large CDC events (approaching 1MB limit)? Validate that envelope format with large `before`/`after` payloads doesn't exceed message.max.bytes.
- What happens when consumer lags significantly behind producer? Validate that Kafka retains messages per retention policy (7 days) and lag metrics are visible in Kafka UI.
- How does Kafka behave when KRaft controller becomes unavailable? Validate automatic recovery time and client impact.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST execute performance benchmark producing 1000 messages per second to Kafka for at least 60 seconds
- **FR-002**: System MUST measure and record Kafka broker startup time from container start to ready state
- **FR-003**: System MUST measure throughput (messages/second), latency (p50, p95, p99), and resource usage (CPU, memory, disk) during performance tests
- **FR-004**: System MUST test at-least-once delivery by producing messages, restarting broker mid-stream, and verifying zero message loss
- **FR-005**: System MUST test consumer offset recovery by simulating consumer restart and verifying no message loss or re-processing gaps
- **FR-006**: System MUST simulate Debezium CDC workload (initial snapshot + streaming changes) and validate Kafka handles load without errors
- **FR-007**: System MUST generate performance report with metrics, graphs, and recommendations in markdown format
- **FR-008**: System MUST generate delivery guarantee test report documenting message loss, duplicate rate, and recovery times
- **FR-009**: System MUST validate that CDC events in Kafka topics use envelope format with before/after/op/source fields
- **FR-010**: System MUST measure consumer lag metrics and validate visibility in Kafka UI
- **FR-011**: System MUST provide integration tests that can be re-run to validate configuration changes or upgrades
- **FR-012**: System MUST document performance tuning recommendations based on benchmark results

### Key Entities

- **Performance Benchmark**: Test harness producing configurable message volume/rate to Kafka topics with CDC-like payloads
- **Delivery Guarantee Test**: Integration test simulating failures (broker restart, network partition) and validating message delivery semantics
- **Performance Metrics**: Throughput (msg/sec), latency distribution (p50/p95/p99), resource usage (CPU/memory/disk)
- **Test Report**: Markdown document with metrics, graphs, and recommendations for performance and delivery guarantees
- **Baseline Configuration**: Documented Kafka settings validated to meet performance and reliability requirements

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Performance benchmark demonstrates Kafka handles ≥1000 messages per second with <100ms p95 latency
- **SC-002**: Kafka broker startup time measured at <10 seconds from container start to ready state
- **SC-003**: At-least-once delivery tests show 0% message loss under broker restart scenarios (duplicates acceptable)
- **SC-004**: Consumer offset recovery tests show 0% message loss and <5 second recovery time after consumer restart
- **SC-005**: CDC workload simulation (895K snapshot) completes without errors and memory usage stays <2GB
- **SC-006**: Performance report generated with all required metrics (throughput, latency, resource usage) and tuning recommendations
- **SC-007**: Delivery guarantee report documents test results for all failure scenarios (broker restart, consumer restart, network partition)
- **SC-008**: All integration tests are automated and can be re-run with `make test-kafka-performance` and `make test-kafka-delivery`

## Assumptions

- **A-001**: Feature 002 (Debezium CDC Setup) is complete with Kafka broker, CDC topics, and Debezium connector operational
- **A-002**: At-least-once delivery configuration from Feature 002 is the target for validation (not exactly-once or at-most-once)
- **A-003**: Performance tests will use envelope format CDC events matching Debezium output structure
- **A-004**: Single Kafka broker is sufficient for development; performance goals reflect single-broker expectations
- **A-005**: Docker host has sufficient resources (4GB RAM, 20GB disk) to run performance tests without host constraints
- **A-006**: Performance benchmarks will use realistic CDC event sizes (1-10KB per message based on actual table schemas)
- **A-007**: Delivery guarantee tests can safely restart Kafka broker without impacting PostgreSQL or other services
- **A-008**: Kafka UI (port 8081) provides sufficient monitoring for observing test metrics

## Performance Testing Strategy

### Benchmark Scenarios

1. **Throughput Test**: Produce 1000 msg/sec for 60 seconds, measure acceptance rate and latency
2. **Burst Test**: Produce 5000 msg/sec for 10 seconds, measure broker backpressure behavior
3. **Sustained Load Test**: Produce 500 msg/sec for 5 minutes, measure resource stability
4. **Snapshot Simulation**: Replay 895K CDC events as fast as possible, measure completion time and peak resource usage
5. **Startup Test**: Measure broker cold start time (fresh container) and warm restart time (existing data)

### Delivery Guarantee Test Scenarios

1. **Broker Restart Mid-Production**: Produce 1000 messages, restart broker at message 500, verify all 1000 received
2. **Consumer Restart Mid-Consumption**: Consume 1000 messages, restart consumer at message 500, verify no gaps or duplicates (duplicates ok with at-least-once)
3. **Network Partition Simulation**: Pause Kafka container for 10 seconds during production, resume, verify no loss
4. **Debezium Offset Recovery**: Restart Debezium connector, verify CDC resumes from last committed offset
5. **Multiple Consumer Groups**: Run 2 consumer groups simultaneously, verify both receive all messages independently

## Test Environment

- **Kafka Broker**: Existing Confluent Platform 7.6.0 from Feature 002
- **Test Tools**:
  - `kafka-producer-perf-test` (built-in Kafka tool)
  - `kafka-consumer-perf-test` (built-in Kafka tool)
  - Custom bash scripts for CDC workload simulation
  - Docker stats for resource monitoring
- **Metrics Collection**:
  - Kafka UI for visual monitoring
  - Docker stats for CPU/memory/disk
  - Kafka metrics exported via JMX (if needed)
  - Test scripts output JSON with metrics

## Out of Scope

- Multi-broker cluster performance testing (single broker only)
- Exactly-once or at-most-once delivery testing (at-least-once only)
- Consumer application implementation (that's Feature 004+)
- Schema Registry performance (not using Schema Registry)
- Kafka Streams performance (not using Streams)
- Production-grade monitoring (Prometheus/Grafana) - using Kafka UI only
- Performance tuning implementation (this feature validates current config, documents recommendations)
- Security testing (SSL/TLS, SASL) - development environment only
- Kafka Connect performance tuning (Debezium performance is Feature 002 scope)

## References

- Kafka Performance Testing Documentation
- Kafka Producer/Consumer Performance Tools
- Debezium CDC Event Envelope Format
- At-Least-Once Delivery Semantics
- Feature 002: Debezium CDC Setup (prerequisite)
