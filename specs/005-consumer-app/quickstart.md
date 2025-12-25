# Consumer Quickstart

Run the consumer after Kafka, Debezium, and OpenSearch are available.

## Prerequisites

- Kafka running (`make start-kafka`)
- Debezium connector registered (`make start-cdc`)
- OpenSearch running

## Start Consumer

```bash
docker compose up -d consumer
```

## Verify

- Check logs for processed events:
  ```bash
  docker compose logs -f consumer --tail=200
  ```
- Confirm documents appear in OpenSearch indices.

## Stop

```bash
docker compose stop consumer
```
