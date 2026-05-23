# Data Model: Test Data Service

**Status**: Updated to canonical PostgreSQL schema
**Source**: `postgres/init/01-create-schema.sql`

The producer API writes directly to the normalized dataset tables so Debezium emits CDC events with the same fields consumed by the rest of the pipeline.

## User / Channel

| Field | Type | Constraint |
|---|---|---|
| `channel_id` | VARCHAR(255) | Primary key |
| `channel_name` | VARCHAR(255) | Required |
| `created_at` | TIMESTAMP | Default current timestamp |
| `updated_at` | TIMESTAMP | Updated by trigger |

## Video

| Field | Type | Constraint |
|---|---|---|
| `video_id` | VARCHAR(255) | Primary key |
| `title` | TEXT | Required |
| `category` | VARCHAR(100) | Optional |
| `created_at` | TIMESTAMP | Default current timestamp |
| `updated_at` | TIMESTAMP | Updated by trigger |

## Comment

| Field | Type | Constraint |
|---|---|---|
| `comment_id` | VARCHAR(255) | Primary key |
| `video_id` | VARCHAR(255) | FK -> `videos(video_id)` |
| `channel_id` | VARCHAR(255) | FK -> `users(channel_id)` |
| `comment_text` | TEXT | Required |
| `likes` | INTEGER | Default 0 |
| `replies` | INTEGER | Default 0 |
| `published_at` | TIMESTAMP | Optional |
| `sentiment_label` | VARCHAR(50) | Optional |
| `country_code` | VARCHAR(10) | Optional |
| `created_at` | TIMESTAMP | Default current timestamp |
| `updated_at` | TIMESTAMP | Updated by trigger |

## API Behavior

- Create requests may supply IDs; if omitted, the producer generates prefixed string IDs (`channel_*`, `video_*`, `comment_*`).
- Update requests take the entity ID from the URL path and update mutable fields only.
- Delete requests remove the row and rely on PostgreSQL foreign key cascade for dependent comments.
- Foreign key violations return `409 Conflict`; missing rows on update/delete return `404 Not Found`.
