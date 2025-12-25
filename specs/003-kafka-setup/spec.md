# Feature Specification: Kafka Broker Configuration with Delivery Guarantees

**Feature Branch**: `003-kafka-setup`
**Created**: 2025-12-25
**Status**: Draft
**Input**: User description: "kafka configs, especially for delivery mode choice"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Deploy Kafka Broker with Chosen Delivery Semantics (Priority: P1)

As a developer, I need to deploy a Kafka broker with configured delivery guarantees (at-least-once, at-most-once, or exactly-once), so I can ensure the data sync pipeline handles messages with appropriate reliability for the OpenSearch use case.

**Why this priority**: This is the foundational messaging infrastructure. Without Kafka properly configured with appropriate delivery semantics, the entire data-sync-opensearch pipeline cannot reliably transport CDC events from Debezium to the consumer application.

**Independent Test**: Can be fully tested by deploying Kafka broker, producing test messages with the configured delivery mode, and verifying message delivery behavior matches expected semantics (no loss, no duplication, or both depending on choice). Delivers immediate value by providing reliable message transport.

**Acceptance Scenarios**:

1. **Given** no existing Kafka broker, **When** developer runs deploy command, **Then** Kafka broker container starts successfully with configured delivery mode settings (KRaft mode)
2. **Given** Kafka broker is running, **When** developer produces test message to a topic, **Then** message is accepted and available for consumption according to configured delivery guarantees
3. **Given** Kafka is configured with chosen delivery mode, **When** developer checks broker configuration, **Then** system reports delivery semantics settings (acks, idempotence, retries) matching the selected mode

---

### User Story 2 - Verify Delivery Guarantees Under Failure Scenarios (Priority: P2)

As a developer, I need to verify that Kafka maintains the configured delivery guarantees even during broker failures or network issues, so I can trust the pipeline won't lose or duplicate critical CDC events.

**Why this priority**: Essential for validating reliability promises. Delivery guarantees only matter if they hold during failures, but broker must work first (depends on P1).

**Independent Test**: Can be tested by simulating broker restart, network partition, or producer failure and verifying message delivery behavior matches configured semantics.

**Acceptance Scenarios**:

1. **Given** Kafka is configured for at-least-once delivery, **When** broker restarts during message production, **Then** no messages are lost but duplicates may occur
2. **Given** Kafka is configured for at-most-once delivery, **When** network failure occurs during acknowledgment, **Then** producer doesn't retry and some messages may be lost
3. **Given** Kafka is configured for exactly-once delivery, **When** producer sends messages and broker fails mid-transaction, **Then** messages are either fully committed or fully rolled back with no loss or duplication

---

### User Story 3 - Monitor Kafka Performance and Health (Priority: P3)

As a developer, I need to monitor Kafka broker health, throughput, and lag metrics, so I can detect performance issues or capacity constraints before they impact the sync pipeline.

**Why this priority**: Important for operational visibility but not required for basic message transport functionality.

**Independent Test**: Can be tested by accessing monitoring dashboards or commands and verifying they display broker metrics, topic statistics, and consumer lag.

**Acceptance Scenarios**:

1. **Given** Kafka broker is running, **When** developer accesses monitoring interface, **Then** system displays broker status, topic count, partition distribution, and throughput metrics
2. **Given** messages are being produced to topics, **When** developer checks topic metrics, **Then** system shows message rate, size, and retention statistics per topic
3. **Given** consumers are reading from topics, **When** developer queries consumer lag, **Then** system reports offset lag for each consumer group and partition

---

### Edge Cases

- What happens when the KRaft controller becomes unavailable? Kafka broker should recover automatically after controller restart; errors should be logged with clear remediation steps.
- How does system handle disk full on Kafka broker? Broker should stop accepting new messages and log clear error message about disk space; producers receive error and can retry after space is freed.
- What happens when producer sends messages faster than broker can persist? Broker applies backpressure by blocking producer requests until buffer space is available; producer may timeout if backpressure exceeds configured timeout.
- How does system handle topic with replication factor greater than available brokers? Topic creation should fail with clear error message indicating insufficient brokers for requested replication factor.
- What happens during Kafka broker rolling restart? With proper replication (factor ≥ 2), no message loss occurs; producers and consumers experience brief latency spike but remain available.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST deploy Kafka broker via Docker Compose with configurable delivery mode (at-least-once, at-most-once, or exactly-once) using KRaft mode
- **FR-002**: System MUST configure Kafka broker with settings appropriate for chosen delivery semantics (acks, enable.idempotence, retries, max.in.flight.requests)
- **FR-003**: System MUST create topics for CDC events from Debezium (dbserver.public.videos, dbserver.public.users, dbserver.public.comments) with configurable replication factor and partition count
- **FR-004**: System MUST provide producer configuration template matching chosen delivery mode for Debezium connector
- **FR-005**: System MUST provide consumer configuration template matching chosen delivery mode for sync consumer application
- **FR-006**: System MUST configure topic retention policies (time and size) to prevent disk exhaustion while maintaining adequate replay capability
- **FR-007**: System MUST expose Kafka broker on configurable port with environment variable overrides
- **FR-008**: System MUST provide Makefile targets for Kafka lifecycle management (start-kafka, stop-kafka, restart-kafka, status-kafka, create-topics)
- **FR-009**: System MUST include monitoring interface (Kafka UI, AKHQ, or similar) for viewing broker health, topics, partitions, and consumer groups
- **FR-010**: System MUST configure KRaft controller settings for single-node development
- **FR-011**: System MUST document delivery mode trade-offs (performance vs. reliability) with recommended choice for CDC use case
- **FR-012**: System MUST validate topic configuration on startup and report errors for misconfigured replication or partitions
- **FR-013**: System MUST preserve Debezium's default CDC envelope (no unwrap) to retain before/after, source, and timestamp metadata
- **FR-014**: System MUST define CDC message keys using primary key fields to preserve per-entity ordering within a partition

### Key Entities

- **Kafka Broker**: Message broker providing persistent, ordered, distributed commit log for CDC events, configured with delivery guarantee settings
- **Topic**: Named category for messages with configured partitions, replication factor, retention policy, and compaction strategy
- **Partition**: Ordered, immutable sequence of messages within a topic, enabling parallel consumption and providing ordering guarantee per partition
- **Producer Configuration**: Settings controlling message delivery behavior including acknowledgment level (acks), idempotence, retries, and batching
- **Consumer Configuration**: Settings controlling message consumption behavior including offset management, isolation level, and session timeout
- **Delivery Semantics**: Guarantee level for message delivery - at-most-once (may lose messages), at-least-once (may duplicate), or exactly-once (no loss, no duplication)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developer can deploy complete Kafka infrastructure (Kafka + monitoring UI) in under 5 minutes using single Makefile command
- **SC-002**: Kafka broker handles 1000 messages per second throughput without accumulating lag or consuming excessive memory
- **SC-003**: Messages published with configured delivery mode exhibit expected guarantees under normal operation (0% loss for at-least-once/exactly-once, 0% duplication for at-most-once/exactly-once)
- **SC-004**: Broker remains available during planned rolling restart with <10 seconds of increased latency
- **SC-005**: Topic creation completes in under 5 seconds with successful partition assignment across brokers
- **SC-006**: Monitoring UI loads and displays broker metrics in under 3 seconds
- **SC-007**: System provides clear error messages for 100% of configuration issues (insufficient brokers, invalid retention, etc.)
- **SC-008**: Broker recovers automatically from transient controller restarts (<1 minute) without manual intervention
- **SC-009**: CDC messages consumed from Kafka include Debezium envelope fields required for consistent replay (before/after, op, source, ts_ms)

## Assumptions

- **A-001**: Single Kafka broker is sufficient for development (production would require multiple brokers for high availability)
- **A-002**: Kafka runs in KRaft mode (single node) for development use
- **A-003**: Default delivery mode of **at-least-once** is acceptable for CDC use case where consumer can handle duplicate events idempotently
- **A-004**: Topic replication factor of 1 is acceptable for development (no fault tolerance required)
- **A-005**: Default partition count of 1 per topic is acceptable for development workload
- **A-006**: Docker host has sufficient disk space for Kafka data and logs (minimum 10GB recommended)
- **A-007**: Kafka 3.5+ is compatible with Debezium 2.5+ configured in feature 002
- **A-008**: Default retention period of 7 days provides adequate replay window for development and troubleshooting
- **A-009**: Monitoring UI accessed via localhost without authentication is acceptable for development
- **A-010**: Producer and consumer applications will be configured with matching delivery semantics to Kafka broker settings

## CDC Event Contract (Default Debezium Envelope)

The default CDC message format is the Debezium envelope (no unwrap SMT). This preserves before/after images and source metadata needed for consistent replay and idempotent sync. Unwrap can be introduced later, but it is not the default for this project.

### Unwrap vs Envelope (Decision Table)

| Choice | Payload Shape | Pros | Cons | Best When |
|---|---|---|---|---|
| **Envelope (default)** | `payload.before/after/op/source/ts_ms` | Full CDC metadata, supports deletes/updates with before/after, easier replay | Larger payload, more parsing in consumer | Auditable CDC, consistent replay, debugging |
| **Unwrap SMT** | `after` only (optional metadata fields) | Simpler consumer, smaller payload, easy indexing | Loses `before` unless added separately, delete handling is trickier | Direct indexing where minimal metadata is fine |

**Envelope shape (schemaless JSON example):**
```json
{
  "payload": {
    "before": { "comment_id": "123", "text": "old" },
    "after": { "comment_id": "123", "text": "new" },
    "op": "u",
    "source": { "db": "app", "schema": "public", "table": "comments", "lsn": 123456 },
    "ts_ms": 1710000000000
  }
}
```

**Key requirements:**
- **Message key**: primary key value (e.g., `comment_id`) to preserve per-entity ordering within a partition.
- **Operation types**: `c` (create), `u` (update), `d` (delete), `r` (snapshot read).
- **Deletes**: `before` carries the prior state; `after` is null.
- **Ordering**: consumers must handle at-least-once delivery with idempotent upserts keyed by primary key.
- **Optimistic lock**: `after.updated_at` is required for consumers to ignore stale events.

## Delivery Mode Recommendations

Based on industry best practices and the project's CDC use case:

### At-Least-Once Delivery (Recommended for CDC)

**Configuration**:
- Producer: `acks=all`, `retries=Integer.MAX_VALUE`, `enable.idempotence=false`
- Consumer: `enable.auto.commit=false` (manual offset commits after processing)

**Characteristics**:
- **Guarantees**: No message loss
- **Trade-off**: Possible message duplication during retries or failures
- **Performance**: Good throughput, moderate latency
- **Complexity**: Consumer must handle duplicates idempotently

**Recommended for**: CDC pipelines where consumer can deduplicate (e.g., upsert to OpenSearch by ID)

### At-Most-Once Delivery

**Configuration**:
- Producer: `acks=0` or `acks=1`, `retries=0`
- Consumer: `enable.auto.commit=true`

**Characteristics**:
- **Guarantees**: No message duplication
- **Trade-off**: Possible message loss during failures
- **Performance**: Highest throughput, lowest latency
- **Complexity**: Simple consumer implementation

**Recommended for**: Metrics, logs, or other lossy use cases (NOT recommended for CDC)

### Exactly-Once Delivery

**Configuration**:
- Producer: `acks=all`, `enable.idempotence=true`, `transactional.id=unique-id`
- Consumer: `isolation.level=read_committed`

**Characteristics**:
- **Guarantees**: No message loss AND no duplication
- **Trade-off**: Lowest throughput, highest latency, increased complexity
- **Performance**: Significant overhead from transactions
- **Complexity**: Requires transactional producer/consumer coordination

**Recommended for**: Financial transactions, billing (probably overkill for CDC to search index)

### Recommendation for This Project

**Suggested**: At-least-once delivery
- CDC events from Debezium are naturally idempotent when using document ID
- OpenSearch upsert operations handle duplicates correctly
- Simpler configuration than exactly-once
- Better performance than exactly-once for similar practical guarantees

## Configuration Recommendations

### Broker Settings

- **Replication Factor**: 1 (development), 3 (production)
- **Min In-Sync Replicas**: 1 (development), 2 (production)
- **Log Retention**: 7 days (time), 1GB per partition (size)
- **Log Segment Size**: 1GB (triggers new segment creation)
- **Compression**: `lz4` or `snappy` (good balance of CPU vs. size)

### Topic Settings

- **Partitions**: 1 (development), 3-6 (production based on consumer parallelism)
- **Cleanup Policy**: `delete` (time/size based retention, not compaction)
- **Message Max Size**: 1MB (adequate for CDC events)

### Producer Settings (At-Least-Once)

- **acks**: `all` (wait for all in-sync replicas)
- **retries**: `Integer.MAX_VALUE` (keep retrying)
- **max.in.flight.requests.per.connection**: `5` (default)
- **batch.size**: `16384` bytes (good default)
- **linger.ms**: `10` ms (small batching delay for throughput)

### Consumer Settings (At-Least-Once)

- **enable.auto.commit**: `false` (manual offset management)
- **auto.offset.reset**: `earliest` (consume from beginning on first run)
- **isolation.level**: `read_uncommitted` (not using transactions)
- **max.poll.records**: `500` (balance memory vs. processing time)

### Monitoring UI Settings

- **Recommended Tool**: AKHQ (formerly KafkaHQ) or Kafka UI
- **Port**: 8080 (configurable)
- **Features**: Topic browsing, consumer group monitoring, message viewing, configuration inspection

## Out of Scope

- Multi-broker Kafka cluster for high availability
- Kafka Streams or ksqlDB for stream processing
- Schema Registry for Avro message schemas (using JSON format)
- Kafka security (SSL/TLS, SASL authentication, ACLs)
- Kafka MirrorMaker for cross-cluster replication
- Advanced topic compaction strategies
- Kafka Connect distributed mode (covered in feature 002 as standalone)
- Production-grade monitoring (Prometheus + Grafana dashboards)
- Performance tuning beyond recommended defaults

## References

- Kafka Delivery Semantics Documentation
- Kafka Producer/Consumer Configuration Best Practices
- Kafka KRaft Deployment Guidelines
- Docker Compose Networking for Kafka
