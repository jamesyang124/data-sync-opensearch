# Implementation Plan: Debezium CDC Configuration

**Branch**: `002-debezium-config` | **Date**: 2025-12-25 | **Spec**: [spec.md](spec.md)

## Summary

Configure Debezium PostgreSQL connector to capture CDC events from 3-table schema (videos, users, comments), publish to Kafka topics, include web UI for monitoring (Kafka Connect UI or Debezium UI), and provide Makefile targets for connector lifecycle management.

**Technical Approach**: Debezium Connect in standalone mode via Docker Compose, PostgreSQL connector configuration JSON, Kafka Connect REST API for management, web UI for visual monitoring.

## Technical Context

**Language/Version**: JSON for connector configuration, Bash for scripts, Docker Compose YAML
**Primary Dependencies**: Debezium Connect 2.5+ (Docker image), PostgreSQL JDBC driver, Kafka broker from feature 003, Kafka Connect UI
**Storage**: Connector offset storage in Kafka topics, PostgreSQL replication slot for CDC
**Testing**: Integration tests validating connector registration, CDC event capture, offset management
**Target Platform**: Docker Desktop for local development
**Project Type**: Infrastructure configuration (CDC connector + UI)
**Performance Goals**: CDC latency <5 seconds (95th percentile), initial snapshot 50K records in <2 minutes
**Constraints**: Standalone mode (single connector instance), development-only configuration
**Scale/Scope**: 3 PostgreSQL tables monitored, 3 Kafka topics created, 1 connector configuration

## Constitution Check

✅ **ALL GATES PASSED**

- Plugin Architecture: Connector config as JSON (extensible for new tables)
- Event-Driven Integration: CDC events published to Kafka (PostgreSQL → Debezium → **Kafka**)
- Integration Testing: Tests for connector registration, CDC capture, offset recovery
- Observability: Web UI for monitoring, REST API for status, connector logs
- Docker-First: Debezium Connect as Docker service

## Project Structure

```text
debezium/
├── connectors/
│   └── postgres-connector.json    # Connector configuration
├── scripts/
│   ├── register-connector.sh      # POST connector config to REST API
│   ├── check-connector-status.sh  # GET connector status
│   └── delete-connector.sh        # DELETE connector
└── config/
    └── connect-standalone.properties  # Kafka Connect worker config

docker-compose.yml           # Add Debezium Connect and UI services
Makefile                    # Add CDC targets (start-cdc, stop-cdc, etc.)
tests/integration/debezium/  # Integration tests
```
