# Kafka Setup

Kafka broker configuration for the CDC pipeline (KRaft mode, single-node).

## Contents

- `config/` - Broker settings notes
- `scripts/` - Topic creation and helper scripts
- `tests/` - Integration test scripts

## Common Commands

```bash
make start-kafka
make create-topics
make status-kafka
make stop-kafka
```

## Monitoring

Kafka UI is available at `http://localhost:8081`.

## Broker Settings (KRaft)

Kafka runs in single-node KRaft mode for local development.

**Defaults**

- Delivery mode: at-least-once (producer `acks=all`, retries enabled)
- Replication factor: 1 (development)
- Min in-sync replicas: 1
- Controller: single-node KRaft (broker + controller)
- Log retention: default broker settings (adjust via env if needed)

**Docker Compose Environment**

Key settings are configured in `docker-compose.yml`:

- `KAFKA_PROCESS_ROLES=broker,controller`
- `KAFKA_CONTROLLER_QUORUM_VOTERS=1@kafka:29093`
- `KAFKA_LISTENERS=PLAINTEXT://kafka:9092,CONTROLLER://kafka:29093`
- `KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://kafka:9092`
- `KAFKA_MIN_INSYNC_REPLICAS=1`
