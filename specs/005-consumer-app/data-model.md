# Data Model: Consumer Event Handling

**Feature**: 005-consumer-app | **Date**: 2025-12-25  
**Purpose**: Define the CDC event shape and document mapping rules for the consumer

## CDC Event Envelope (Debezium)

```json
{
  "payload": {
    "op": "u",
    "before": { "video_id": "video_123", "updated_at": "2024-06-20T08:10:00Z" },
    "after": { "video_id": "video_123", "title": "New", "updated_at": "2024-06-20T08:12:00Z" },
    "ts_ms": 1710000000000,
    "source": { "db": "app", "schema": "public", "table": "videos" }
  }
}
```

## Mapping Rules

- **Document ID**: Use the primary key from `payload.after` (or `payload.before` for deletes).
- **Insert/Update**: Upsert the full `payload.after` document into the target index.
- **Delete**: Delete by document ID derived from `payload.before`.
- **Optimistic Lock**: Compare `updated_at` in the event to the stored document; skip stale updates.

## Topic → Index Mapping

| Kafka Topic | OpenSearch Index | Primary Key |
|------------|------------------|-------------|
| `dbserver.public.videos` | `videos_index` | `video_id` |
| `dbserver.public.users` | `users_index` | `channel_id` |
| `dbserver.public.comments` | `comments_index` | `comment_id` |
