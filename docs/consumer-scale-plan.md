# Consumer Scale Plan

This project scales the CDC indexer with normal Kafka consumer groups. The local 500-600 RPS target uses a conservative default of 6 partitions per CDC topic and 4 consumer replicas.

## Local Target

- CDC topics: `dbserver.public.users`, `dbserver.public.videos`, `dbserver.public.comments`
- DLQ topics: matching `.dlq` topics
- Partition target: `6` per CDC and DLQ topic
- Consumer target: `4` replicas for 500-600 producer RPS
- Lag target: `0` lag after the benchmark cool-down, and no sustained lag growth during steady load

## Commands

```bash
CDC_TOPIC_PARTITIONS=6 make scale-cdc-topics
curl -fsS -X POST http://localhost:8090/api/scale \
  -H 'Content-Type: application/json' \
  -d '{"replicas":4}' | jq '.'
```

Run the benchmark from the ops console or API:

```bash
curl -fsS -X POST http://localhost:8090/api/benchmark \
  -H 'Content-Type: application/json' \
  -d '{"scenario":"sustained","target_rps":500,"duration":"15s","consumer_replicas":4,"setup_users":100,"setup_videos":50,"setup_comments":50}' | jq '.'
```

Check lag:

```bash
docker compose exec -T kafka kafka-consumer-groups \
  --bootstrap-server kafka:9092 \
  --describe \
  --group cdc-consumer-group
```

## Ordering Constraints

Debezium produces keyed records by table primary key, and Kafka assigns records to partitions by key. The consumer processes each claimed partition sequentially so one entity's create/update/delete sequence is preserved. `source_ts_ms` and `updated_at` stale-update checks are a second guard for replay and retry cases.

Do not use unkeyed worker-pool concurrency for the primary CDC indexer. If higher per-consumer concurrency is needed later, use keyed worker lanes that preserve per-key order. Kafka share groups are deferred until WAL/LSN external versioning and delete tombstone handling are implemented and verified.
