# Implementation Plan: Kafka Broker Configuration with Delivery Guarantees

**Branch**: `003-kafka-config` | **Date**: 2025-12-25 | **Spec**: [spec.md](spec.md)

## Summary

Deploy Kafka broker with Zookeeper, configure delivery semantics (at-least-once recommended for CDC), create topics for 3 CDC event streams (videos, users, comments), include monitoring UI (AKHQ or Kafka UI), and provide Makefile targets for lifecycle management.

**Technical Approach**: Kafka 3.5+ with Zookeeper in Docker Compose, topic auto-creation or explicit creation scripts, at-least-once delivery configuration (acks=all, retries=max), monitoring UI for visual management.

## Technical Context

**Language/Version**: YAML for Docker Compose, properties files for Kafka config, Bash for scripts
**Primary Dependencies**: Kafka 3.5+ (Docker image), Zookeeper 3.8+ (Docker image), AKHQ or Kafka UI for monitoring
**Storage**: Docker volumes for Kafka data and Zookeeper state
**Testing**: Integration tests for broker health, topic creation, message delivery guarantees
**Target Platform**: Docker Desktop for local development
**Project Type**: Infrastructure configuration (message broker)
**Performance Goals**: 1000 msg/sec throughput, <10s startup time
**Constraints**: Single broker (no cluster), development-only configuration
**Scale/Scope**: 3 topics for CDC, at-least-once delivery mode

## Constitution Check

✅ **ALL GATES PASSED**

- Plugin Architecture: Topic configuration extensible
- Event-Driven Integration: Kafka as message backbone (**Debezium** → Kafka → **Consumer**)
- Integration Testing: Tests for delivery guarantees, topic creation
- Observability: Monitoring UI, broker metrics, consumer lag tracking
- Docker-First: Kafka and Zookeeper as Docker services

## Project Structure

```text
kafka/
├── config/
│   └── server.properties      # Kafka broker configuration
├── scripts/
│   ├── create-topics.sh       # Create CDC topics explicitly
│   └── check-topics.sh        # List topics and describe
└── monitoring/
    └── akhq-config.yml        # AKHQ configuration (if used)

docker-compose.yml           # Add Kafka, Zookeeper, UI services
Makefile                    # Add Kafka targets
tests/integration/kafka/     # Integration tests
```
