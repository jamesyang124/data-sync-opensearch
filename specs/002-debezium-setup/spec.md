# Feature Specification: Debezium CDC Configuration

**Feature Branch**: `002-debezium-setup`
**Created**: 2025-12-25
**Status**: Draft
**Input**: User description: "the debezium configuration suggestion"

## Clarifications

### Session 2025-12-25

- Q: Should the feature include a web UI for monitoring Debezium, or is command-line/API-based monitoring sufficient? → A: Include web UI (Kafka Connect UI, Debezium UI, or similar) for visual monitoring of connector status, metrics, and configuration

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Configure PostgreSQL CDC Connector (Priority: P1)

As a developer, I need to configure Debezium to capture changes from the PostgreSQL database and publish them to Kafka topics, so I can establish the foundation for the data sync pipeline to OpenSearch.

**Why this priority**: This is the core CDC functionality. Without Debezium properly configured to capture PostgreSQL changes, the entire data-sync-opensearch pipeline cannot function.

**Independent Test**: Can be fully tested by starting Debezium connector, making changes to PostgreSQL tables (insert, update, delete), and verifying CDC events appear in corresponding Kafka topics. Delivers immediate value by enabling change data capture.

**Acceptance Scenarios**:

1. **Given** PostgreSQL database is running with sample data, **When** developer applies Debezium connector configuration, **Then** connector starts successfully and begins capturing table changes
2. **Given** Debezium connector is running, **When** a new record is inserted into any monitored table, **Then** INSERT event appears in the corresponding Kafka topic within 5 seconds
3. **Given** Debezium connector is active, **When** developer checks connector status, **Then** system reports healthy status, offset position, and list of monitored tables

---

### User Story 2 - Monitor CDC Health and Performance (Priority: P2)

As a developer, I need to monitor Debezium connector health, lag metrics, and error conditions, so I can detect and resolve issues before they impact data synchronization.

**Why this priority**: Essential for operational readiness. Monitoring enables proactive issue detection, but the connector must work first (depends on P1).

**Independent Test**: Can be tested by accessing health check endpoints and metrics, simulating failure scenarios, and verifying alerts/status reporting work correctly.

**Acceptance Scenarios**:

1. **Given** Debezium connector is running, **When** developer opens web UI in browser, **Then** UI displays connector status, current offset lag, and any error conditions in visual dashboard
2. **Given** PostgreSQL becomes temporarily unavailable, **When** connection is restored, **Then** Debezium automatically reconnects and resumes capturing changes from last committed offset (visible in web UI status)
3. **Given** Debezium encounters a schema change, **When** developer checks web UI or logs, **Then** system provides clear message indicating whether change was handled automatically or requires manual intervention

---

### User Story 3 - Manage Connector Lifecycle (Priority: P3)

As a developer, I need to start, stop, restart, and reconfigure the Debezium connector without data loss, so I can manage the CDC pipeline during development and troubleshooting.

**Why this priority**: Important for operational flexibility but not required for basic pipeline functionality. Developers can restart containers as fallback.

**Independent Test**: Can be tested by executing lifecycle commands and verifying connector state transitions correctly while preserving offset positions.

**Acceptance Scenarios**:

1. **Given** Debezium connector is running, **When** developer executes stop command, **Then** connector gracefully shuts down after flushing pending events and commits final offset
2. **Given** connector is stopped, **When** developer executes start command, **Then** connector resumes from last committed offset without missing or duplicating events
3. **Given** developer updates connector configuration, **When** restart command is executed, **Then** new configuration applies and connector resumes operation without data loss

---

### Edge Cases

- What happens when Kafka broker becomes unavailable? Debezium should buffer events in memory (up to configured limit) and pause CDC until Kafka is reachable, then resume publishing.
- How does system handle PostgreSQL schema changes to monitored tables? System should detect schema evolution and either auto-adapt (for compatible changes) or pause with clear error message for breaking changes.
- What happens when connector starts with no previous offset (first time setup)? System should provide configurable snapshot mode: initial (capture existing data), schema_only (structure only), or never (start from current position).
- How does system handle extremely high change volume? Connector should apply backpressure, slow down CDC capture rate, and report lag metrics to prevent memory overflow.
- What happens when PostgreSQL transaction log (WAL) is purged before Debezium can read it? System should detect gap and either fail with clear error or trigger re-snapshot depending on configuration.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide Debezium connector configuration for PostgreSQL CDC targeting the 3-table schema (videos, users, comments)
- **FR-002**: System MUST configure Debezium to publish change events to Kafka topics with topic naming pattern matching table names (e.g., dbserver.public.videos, dbserver.public.users, dbserver.public.comments)
- **FR-003**: System MUST capture INSERT, UPDATE, and DELETE operations for all monitored tables with before/after state for updates and deletes
- **FR-004**: System MUST provide connector deployment via Docker Compose alongside PostgreSQL and Kafka containers
- **FR-005**: System MUST configure PostgreSQL logical replication (wal_level=logical) to enable CDC
- **FR-006**: System MUST provide web UI (such as Kafka Connect UI or Debezium UI) for visual monitoring of connector status, offset lag, configuration, and error conditions
- **FR-006a**: System MUST deploy web UI via Docker Compose with browser access on documented port
- **FR-007**: System MUST handle initial snapshot on first connector start, capturing existing table data before streaming changes
- **FR-008**: System MUST persist connector offsets to prevent duplicate or missing events across restarts
- **FR-009**: System MUST provide Makefile targets for connector lifecycle management (start-cdc, stop-cdc, restart-cdc, status-cdc)
- **FR-010**: System MUST configure appropriate transformations (e.g., unwrap envelope, route by table) for clean event structure
- **FR-011**: System MUST document connector configuration parameters with explanations and recommended values
- **FR-012**: System MUST handle connector failures gracefully with automatic restart and recovery from last committed offset

### Key Entities

- **Debezium Connector**: CDC engine that monitors PostgreSQL transaction log and publishes change events to Kafka, configured via JSON connector definition
- **Connector Configuration**: JSON document specifying database connection, monitored tables, snapshot mode, topic routing, transformations, and performance tuning parameters
- **Change Event**: Structured message representing a database operation (INSERT/UPDATE/DELETE) containing operation type, before/after row state, transaction metadata, and timestamp
- **Offset**: Position marker in PostgreSQL WAL (Write-Ahead Log) tracking last processed transaction, persisted to Kafka offset topic for resumability
- **Snapshot**: Initial bulk capture of existing table data performed when connector first starts or after offset loss, configurable to run always, initially, or never
- **Kafka Topic**: Destination for change events, one topic per monitored table with configurable partitioning and retention
- **Monitoring Web UI**: Browser-based dashboard (Kafka Connect UI, Debezium UI, or similar open-source tool) providing visual interface for connector status, metrics, configuration viewing, and troubleshooting

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developer can deploy complete CDC pipeline (PostgreSQL + Debezium + Kafka) in under 5 minutes using single Makefile command
- **SC-002**: Change events appear in Kafka within 5 seconds of database operation (95th percentile latency under normal load)
- **SC-003**: Connector successfully captures 100% of database changes without loss or duplication during normal operation and restarts
- **SC-004**: System recovers automatically from transient failures (network hiccups, Kafka unavailability <2 minutes) without manual intervention
- **SC-005**: Initial snapshot of 50K records across 3 tables completes in under 2 minutes
- **SC-006**: Connector handles sustained load of 100 database changes per second without accumulating lag beyond 10 seconds
- **SC-007**: Web UI loads and displays connector status in under 3 seconds
- **SC-008**: Zero data loss during connector stop/restart cycle when using graceful shutdown commands

## Assumptions

- **A-001**: PostgreSQL database from feature 001-postgres-datasource-setup is available and running with sample YouTube comment data
- **A-002**: Kafka broker is deployed via Docker Compose and accessible on default port (documented in docker-compose.yml)
- **A-003**: PostgreSQL is configured with sufficient WAL retention (wal_keep_size or replication slot) to prevent offset loss during connector downtime
- **A-004**: Debezium container has network connectivity to both PostgreSQL and Kafka containers within Docker Compose network
- **A-005**: Default Debezium connector configuration (snapshot.mode=initial, include.schema.changes=true) is acceptable for development use
- **A-006**: Kafka topics are auto-created on first event publication with default partitions (1) and retention (7 days)
- **A-007**: Debezium PostgreSQL connector version 2.5+ is compatible with PostgreSQL 14+ configured in feature 001
- **A-008**: Developers understand basic Debezium concepts (connectors, offsets, snapshots) or can reference provided documentation
- **A-009**: Single Debezium connector instance is sufficient for development (no high-availability requirements)
- **A-010**: JSON-format change events are acceptable (no need for Avro schema registry at this stage)
- **A-011**: Open-source web UI tool (Kafka Connect UI, Debezium UI, or Kafdrop) is acceptable for monitoring without custom metrics implementation
- **A-012**: Web UI accessed via localhost on configured port is acceptable for development use (no authentication required)

## Configuration Recommendations

Based on industry best practices and the project constitution (Integration Testing, Observability, Docker-First):

### Core Connector Settings

- **Connector Class**: `io.debezium.connector.postgresql.PostgresConnector`
- **Database Hostname/Port**: Reference PostgreSQL service from docker-compose.yml
- **Database Credentials**: Use same .env pattern from feature 001 for consistency
- **Plugin Name**: `pgoutput` (default PostgreSQL logical decoding plugin, no additional installation required)
- **Slot Name**: `debezium_slot` (persistent replication slot for offset tracking)

### Table Selection

- **Table Include List**: `public.videos,public.users,public.comments` (explicit whitelist matching normalized schema)
- **Schema Include List**: `public` (exclude system schemas)

### Snapshot Configuration

- **Snapshot Mode**: `initial` (capture existing data on first run, then stream changes)
- **Snapshot Fetch Size**: `10000` (balance memory vs. speed for 50K record snapshot)

### Topic Routing

- **Topic Prefix**: `dbserver` (creates topics like `dbserver.public.videos`)
- **Topic Per Table**: Enabled (one topic per monitored table for independent consumption)

### Performance Tuning

- **Max Batch Size**: `2048` (events per Kafka batch for throughput)
- **Max Queue Size**: `8192` (internal buffer for backpressure handling)
- **Poll Interval**: `1000ms` (check for WAL changes every second)

### Transformations

- **Unwrap SMT**: Extract `after` payload from change event envelope for cleaner consumer processing
- **Add Source Fields**: Include table name, operation type, and timestamp metadata

### Observability

- **Include Schema Changes**: `true` (log DDL events for troubleshooting)
- **Provide Transaction Metadata**: `true` (include transaction ID for event ordering verification)

### Web UI Monitoring

- **Recommended Tool**: Kafka Connect UI or Debezium UI (lightweight, Docker-ready, open-source)
- **Access Port**: Configurable via environment variable (default: 8000 or 8080)
- **Features**: Connector status viewing, configuration inspection, offset monitoring, error display
- **Deployment**: Additional container in docker-compose.yml with volume/network access to Kafka Connect

## Out of Scope

- Multi-connector deployment for high availability
- Custom SMTs (Single Message Transforms) beyond basic unwrap
- Avro schema registry integration
- Kafka Connect distributed mode (using standalone mode for simplicity)
- Advanced filtering or routing logic
- Performance testing beyond single-developer use case
- Custom-built monitoring dashboards (using existing open-source web UI tools instead)
- Web UI authentication/authorization (development use only)

## References

- Debezium PostgreSQL Connector Documentation
- PostgreSQL Logical Replication Configuration
- Kafka Connect API
- Docker Compose Networking Best Practices
