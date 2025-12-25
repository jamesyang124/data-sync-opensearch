# Research Notes: Consumer App

**Feature**: 005-consumer-app | **Date**: 2025-12-25

## CDC Envelope vs Unwrap

Decision: keep Debezium envelope by default.

Rationale:
- Preserves before/after for deletes and update diffs.
- Retains source metadata for debugging and replay.
- Aligns with Kafka feature 003 contract.

## Optimistic Lock with `updated_at`

Decision: use `updated_at` from CDC events to ignore stale updates.

Rationale:
- At-least-once delivery can produce duplicates or out-of-order events.
- Comparing `updated_at` prevents older updates from overwriting newer data.

## Idempotency Strategy

Decision: use PostgreSQL primary key as OpenSearch document ID.

Rationale:
- Upserts become idempotent by default.
- Duplicate events do not create duplicate documents.
