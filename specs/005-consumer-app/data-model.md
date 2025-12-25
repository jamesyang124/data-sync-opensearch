# Data Model: Golang CDC Consumer Application

**Feature**: 005-consumer-app | **Date**: 2025-12-25
**Purpose**: Document data structures and transformations in the consumer application

## Overview

This document defines the data model for three OpenSearch indices that store synchronized data from PostgreSQL via the CDC pipeline. Each index corresponds to a PostgreSQL table from feature 001, with mappings optimized for search use cases.

**Index Design Philosophy**:
- **Denormalized for search**: Indices store complete documents (no joins required during search)
- **Idempotent writes**: Document `_id` matches PostgreSQL primary key for upsert semantics
- **Type-optimized**: Field types chosen for search patterns (text analysis, filtering, sorting, aggregations)
- **Analyzer-configured**: Text fields use standard analyzer for English content tokenization

## Indices

### 1. Videos Index

**Index Name**: `videos_index`

**Purpose**: Store searchable video metadata including engagement metrics for popularity-based ranking

**Document Structure**:

```json
{
  "_id": "video_12345",
  "_source": {
    "video_id": "video_12345",
    "title": "Introduction to Machine Learning",
    "description": "Learn the fundamentals of machine learning including supervised learning, unsupervised learning, and neural networks.",
    "channel_id": "channel_789",
    "view_count": 1250000,
    "like_count": 35000,
    "published_at": "2024-06-15T14:30:00Z",
    "duration_seconds": 1800,
    "category": "Education",
    "tags": ["machine learning", "AI", "tutorial", "python"]
  }
}
```

**Field Mappings**:

| Field | Type | Indexed | Searchable | Sortable | Purpose | Notes |
|-------|------|---------|------------|----------|---------|-------|
| `video_id` | `keyword` | Yes | Exact match | Yes | Unique identifier, document ID | Primary key from PostgreSQL |
| `title` | `text` | Yes | Full-text | No | Primary search field | Standard analyzer, boosted in multi_match queries |
| `description` | `text` | Yes | Full-text | No | Secondary search field | Standard analyzer |
| `channel_id` | `keyword` | Yes | Exact match | Yes | Filter by channel | Foreign key reference (not enforced) |
| `view_count` | `long` | Yes | No | Yes | Popularity sorting, range filters | 64-bit for viral videos |
| `like_count` | `long` | Yes | No | Yes | Engagement scoring | Used in hybrid ranking |
| `published_at` | `date` | Yes | No | Yes | Recency sorting, date range filters | ISO 8601 format |
| `duration_seconds` | `integer` | Yes | No | Yes | Filter by video length | 32-bit sufficient |
| `category` | `keyword` | Yes | Exact match | Yes | Faceted search, filtering | Predefined categories |
| `tags` | `text` with `keyword` subfield | Yes | Both | Yes (keyword) | Search tags, exact match filtering | Array field |

**Index Settings**:
```json
{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0,
    "refresh_interval": "1s",
    "analysis": {
      "analyzer": {
        "default": {
          "type": "standard"
        }
      }
    }
  }
}
```

**Validation Rules**:
- `video_id`: Required, unique (enforced by `_id`)
- `title`: Required, max length 200 characters (application enforced)
- `view_count`: >= 0 (application enforced)
- `like_count`: >= 0 (application enforced)
- `published_at`: Valid ISO 8601 date (OpenSearch validates)
- `category`: Must be from predefined list (application enforced)

**State/Lifecycle**: Documents are immutable once published; updates only change engagement metrics (view_count, like_count)

---

### 2. Users Index

**Index Name**: `users_index`

**Purpose**: Store user/channel information for author lookups and channel-based filtering

**Document Structure**:

```json
{
  "_id": "user_456",
  "_source": {
    "user_id": "user_456",
    "username": "techexplainer",
    "channel_name": "Tech Explained",
    "subscriber_count": 500000,
    "created_at": "2019-03-20T10:15:00Z",
    "verified": true,
    "description": "Making complex technology simple for everyone."
  }
}
```

**Field Mappings**:

| Field | Type | Indexed | Searchable | Sortable | Purpose | Notes |
|-------|------|---------|------------|----------|---------|-------|
| `user_id` | `keyword` | Yes | Exact match | Yes | Unique identifier, document ID | Primary key from PostgreSQL |
| `username` | `text` with `keyword` subfield | Yes | Both | Yes (keyword) | Search authors, exact match | Dual-purpose field |
| `channel_name` | `text` with `keyword` subfield | Yes | Both | Yes (keyword) | Search channels, exact match | Dual-purpose field |
| `subscriber_count` | `long` | Yes | No | Yes | Popularity metric | Used for channel ranking |
| `created_at` | `date` | Yes | No | Yes | Account age | ISO 8601 format |
| `verified` | `boolean` | Yes | Exact match | Yes | Filter verified channels | True/false flag |
| `description` | `text` | Yes | Full-text | No | Channel bio search | Standard analyzer |

**Index Settings**:
```json
{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0,
    "refresh_interval": "1s",
    "analysis": {
      "analyzer": {
        "default": {
          "type": "standard"
        }
      }
    }
  }
}
```

**Validation Rules**:
- `user_id`: Required, unique (enforced by `_id`)
- `username`: Required, max length 50 characters (application enforced)
- `channel_name`: Required, max length 100 characters (application enforced)
- `subscriber_count`: >= 0 (application enforced)
- `verified`: Boolean (OpenSearch validates type)

**State/Lifecycle**: Documents updated when subscriber count changes or verification status granted

---

### 3. Comments Index

**Index Name**: `comments_index`

**Purpose**: Store user comments with sentiment analysis for searchable feedback and engagement tracking

**Document Structure**:

```json
{
  "_id": "comment_7890",
  "_source": {
    "comment_id": "comment_7890",
    "video_id": "video_12345",
    "user_id": "user_456",
    "comment_text": "This is the best explanation of machine learning I've ever seen! Thank you!",
    "sentiment": "positive",
    "like_count": 250,
    "posted_at": "2024-06-16T09:45:00Z",
    "parent_comment_id": null
  }
}
```

**Field Mappings**:

| Field | Type | Indexed | Searchable | Sortable | Purpose | Notes |
|-------|------|---------|------------|----------|---------|-------|
| `comment_id` | `keyword` | Yes | Exact match | Yes | Unique identifier, document ID | Primary key from PostgreSQL |
| `video_id` | `keyword` | Yes | Exact match | Yes | Filter comments by video | Foreign key reference |
| `user_id` | `keyword` | Yes | Exact match | Yes | Filter comments by author | Foreign key reference |
| `comment_text` | `text` | Yes | Full-text | No | Primary search field | Standard analyzer |
| `sentiment` | `keyword` | Yes | Exact match | Yes | Faceted search, filtering | Values: positive, negative, neutral |
| `like_count` | `integer` | Yes | No | Yes | Sort by engagement | 32-bit sufficient for comment likes |
| `posted_at` | `date` | Yes | No | Yes | Recency sorting, date filters | ISO 8601 format |
| `parent_comment_id` | `keyword` | Yes | Exact match | Yes | Filter for replies vs top-level | Nullable field |

**Index Settings**:
```json
{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0,
    "refresh_interval": "1s",
    "analysis": {
      "analyzer": {
        "default": {
          "type": "standard"
        }
      }
    }
  }
}
```

**Validation Rules**:
- `comment_id`: Required, unique (enforced by `_id`)
- `video_id`: Required, references videos_index (application enforced)
- `user_id`: Required, references users_index (application enforced)
- `comment_text`: Required, max length 1000 characters (application enforced)
- `sentiment`: Required, must be "positive", "negative", or "neutral" (application enforced)
- `like_count`: >= 0 (application enforced)
- `parent_comment_id`: Optional, references another comment_id if present

**State/Lifecycle**: Documents are immutable after posting; only like_count can be updated

---

## Relationships

### Cross-Index References

```text
┌─────────────────┐
│  users_index    │
│  (user_id)      │◄───────┐
└─────────────────┘        │
                           │
                           │ channel_id
                           │
┌─────────────────┐        │
│  videos_index   │        │
│  (video_id)     │────────┘
└─────────────────┘
         ▲
         │ video_id
         │
┌─────────────────┐
│ comments_index  │
│ (comment_id)    │
└─────────────────┘
         │
         │ user_id
         │
         ▼
┌─────────────────┐
│  users_index    │
│  (user_id)      │
└─────────────────┘
```

**Relationship Notes**:
- **No foreign key enforcement**: OpenSearch doesn't enforce referential integrity (application responsibility)
- **Denormalized for search**: No join queries required; filter by IDs directly
- **Parent-child comments**: `parent_comment_id` in comments_index enables threaded conversations (self-referencing)

### Query Patterns Using Relationships

**Pattern 1: Get all comments for a video**
```json
{
  "query": {
    "term": { "video_id": "video_12345" }
  },
  "sort": [{ "posted_at": { "order": "desc" }}]
}
```

**Pattern 2: Get all videos by a channel**
```json
{
  "query": {
    "term": { "channel_id": "channel_789" }
  },
  "sort": [{ "view_count": { "order": "desc" }}]
}
```

**Pattern 3: Find replies to a specific comment**
```json
{
  "query": {
    "term": { "parent_comment_id": "comment_7890" }
  }
}
```

---

## Data Synchronization

### CDC Event to Document Mapping

**Insert Operation** (Debezium `op: "c"` create):
```json
// Debezium CDC event
{
  "op": "c",
  "after": {
    "video_id": "video_12345",
    "title": "Introduction to Machine Learning",
    ...
  }
}

// Mapped to OpenSearch operation
POST /videos_index/_doc/video_12345
{
  "video_id": "video_12345",
  "title": "Introduction to Machine Learning",
  ...
}
```

**Update Operation** (Debezium `op: "u"` update):
```json
// Debezium CDC event
{
  "op": "u",
  "before": { "view_count": 1250000 },
  "after": { "view_count": 1250500 }
}

// Mapped to OpenSearch operation (full document upsert)
PUT /videos_index/_doc/video_12345
{
  // ... full document with updated view_count
}
```

**Delete Operation** (Debezium `op: "d"` delete):
```json
// Debezium CDC event
{
  "op": "d",
  "before": {
    "video_id": "video_12345",
    ...
  }
}

// Mapped to OpenSearch operation
DELETE /videos_index/_doc/video_12345
```

### Idempotency

**Strategy**: Use PostgreSQL primary key as OpenSearch `_id`

**Benefit**: Multiple consumer instances can process same CDC event without duplicates
- First write: Document created with `_id=video_12345`
- Second write (duplicate): Document updated with same `_id` (no new document)

**Consumer Implementation** (feature 004):
```go
// Pseudo-code for consumer
documentID := cdcEvent.After.VideoID  // e.g., "video_12345"
indexRequest := opensearch.IndexRequest{
    Index:      "videos_index",
    DocumentID: documentID,  // Enables idempotent upsert
    Body:       marshalToJSON(cdcEvent.After),
}
```

---

## Schema Evolution

### Dynamic Field Handling

**Configuration**: `"dynamic": "true"` (default) allows new fields

**Example**: PostgreSQL schema adds `tags` field later
```sql
-- PostgreSQL migration
ALTER TABLE videos ADD COLUMN tags TEXT[];
```

**Impact on OpenSearch**:
- Consumer sends CDC event with new `tags` field
- OpenSearch dynamically maps `tags` as `text` (or array of text)
- Existing documents don't have `tags` field (null/missing)
- New queries can search `tags` field

**Best Practice**: Update index mapping explicitly for better control:
```bash
# Add tags field with explicit mapping
PUT /videos_index/_mapping
{
  "properties": {
    "tags": {
      "type": "text",
      "fields": {
        "keyword": { "type": "keyword" }
      }
    }
  }
}
```

### Breaking Changes

**Scenario**: Change field type (e.g., `view_count` from `long` to `text`)

**Resolution**: Requires reindexing
1. Create new index with updated mapping (`videos_index_v2`)
2. Reindex data: `POST /_reindex { "source": {"index": "videos_index"}, "dest": {"index": "videos_index_v2"} }`
3. Update consumer to write to new index
4. Optionally create alias: `POST /_aliases { "actions": [{"add": {"index": "videos_index_v2", "alias": "videos_index"}}] }`

---

## Performance Considerations

### Index Size Estimates

**Assumptions** (from spec.md A-004):
- Videos: 1,000 documents × ~500 bytes = 500 KB
- Users: 500 documents × ~300 bytes = 150 KB
- Comments: 8,500 documents × ~400 bytes = 3.4 MB
- **Total**: ~4 MB for demo data

**50K documents** (SC-003):
- 50,000 × ~400 bytes average = 20 MB
- With inverted index overhead: ~50-100 MB

**Conclusion**: Well within 2GB heap capacity (A-007)

### Query Performance

**Factors affecting speed**:
- **Index size**: 50K docs = fast queries (<100ms)
- **Query complexity**: Function_score adds overhead but <500ms target achievable (SC-003)
- **Caching**: Query cache and request cache reduce repeat query latency
- **Refresh interval**: 1s means near real-time search (1 second max delay)

**Optimization**:
- Use `size` parameter to limit results (default 10)
- Use `_source` filtering to return only needed fields
- Avoid deep pagination (offset >10,000 requires `scroll` API)

---

## Validation Summary

**Index Count**: 3 indices ✅ (matches spec.md FR-002)

**Field Type Coverage**:
- Text fields with analyzers ✅ (FR-003, FR-006)
- Keyword fields for exact match ✅ (FR-003)
- Numeric fields for counts ✅ (FR-003)
- Date fields for timestamps ✅ (FR-003)

**Search Capabilities**:
- Full-text search ✅ (title, description, comment_text)
- Exact match filtering ✅ (video_id, category, sentiment)
- Range queries ✅ (view_count, posted_at)
- Aggregations ✅ (category facets, sentiment distribution)

**Alignment with PostgreSQL Schema** (feature 001): ✅ All fields mapped from normalized schema

---

## Next Steps

After data model documentation:
1. ✅ Generate contracts/ (JSON mapping files)
2. Generate quickstart.md (index setup guide)
3. Update agent context with OpenSearch data model
