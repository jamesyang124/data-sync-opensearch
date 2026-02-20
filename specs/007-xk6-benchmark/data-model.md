# Data Model: xk6 Benchmark Suite

**Phase**: 1 — Design
**Date**: 2026-02-20
**Feature**: 007-xk6-benchmark

---

## Overview

The benchmark suite does not own a database. Its "data model" consists of:
1. **Fake record schemas** — the shape of JSON payloads sent to the producer app
2. **Runtime state** — ephemeral collections of resource IDs maintained across the test run for referential integrity
3. **Metric outputs** — the structured report produced at end of run

---

## 1. Request Payload Schemas

Derived from the producer app's domain models (`producer/pkg/models/models.go`).

### User (Create / Update)

```json
{
  "username": "string (unique, format: FirstName_LastName_timestamp)",
  "email":    "string (unique, format: uuid@example.com)"
}
```

| Field | Source | Uniqueness strategy |
|---|---|---|
| `username` | `faker.person.firstName() + faker.person.lastName() + Date.now()` | Timestamp suffix ensures uniqueness per iteration |
| `email` | `faker.string.uuid() + "@example.com"` | UUID prefix guarantees global uniqueness |

### Video (Create)

```json
{
  "user_id":     "UUID (from runtime user pool)",
  "title":       "string (5-word sentence)",
  "description": "string (1 paragraph, ~30 words)",
  "duration":    "integer (seconds, range: 60–7200)"
}
```

| Field | Source |
|---|---|
| `user_id` | Selected randomly from `setup()` user pool |
| `title` | `faker.lorem.sentence(5)` |
| `description` | `faker.lorem.paragraph(1, 3, 10, ' ')` |
| `duration` | `faker.number.intRange(60, 7200)` |

### Comment (Create) — future endpoint

```json
{
  "video_id":     "UUID (from runtime video pool)",
  "user_id":      "UUID (from runtime user pool)",
  "comment_text": "string (1–2 sentences, ~15 words)"
}
```

| Field | Source |
|---|---|
| `video_id` | Selected randomly from `setup()` video pool |
| `user_id` | Selected randomly from `setup()` user pool |
| `comment_text` | `faker.lorem.sentence(15)` |

---

## 2. Runtime State (SharedArray pools)

Populated during `setup()` — the k6 function that runs once before any VU starts.

### User Pool

- **Size**: 200 users (configurable via `SETUP_USERS` env var)
- **Contents**: Array of UUID strings (`user_id` values)
- **Used by**: Video CREATE, Comment CREATE, User UPDATE/DELETE

### Video Pool

- **Size**: 100 videos (configurable via `SETUP_VIDEOS` env var)
- **Contents**: Array of UUID strings (`video_id` values)
- **Used by**: Comment CREATE

### ID Rotation Strategy

- Each VU selects a random index from the pool on each iteration.
- UPDATE and DELETE operations target randomly selected IDs from the pool.
- The pool is read-only during the test; deleted records may cause 404 responses (these are tracked separately, not counted as failures for DELETE operations).

---

## 3. Metric Outputs

### Terminal Summary (human-readable)

Displayed by k6 at test end via `textSummary`. Key rows:

| Metric | Description |
|---|---|
| `http_reqs` | Total request count and rate (RPS) |
| `http_req_duration` | Latency: avg, min, med, max, p(90), p(95), p(99) |
| `http_req_failed` | Error rate (non-2xx responses) |
| `vus` | Current/max VU count |
| `iterations` | Completed iterations count |

### Machine-Readable Summary (`reports/summary.json`)

Full aggregated metric object with all above values in JSON. Suitable for CI artifact upload or dashboard ingestion.

### Raw NDJSON (`reports/raw.ndjson`)

One JSON object per data point sample. Each point includes:
- `metric`: metric name (e.g., `http_req_duration`)
- `data.value`: sample value
- `data.tags`: `{ method, status, url, endpoint }` — the `endpoint` tag enables per-endpoint sub-metric filtering

### PASS/FAIL Verdict

Determined by k6 threshold evaluation:
- **PASS**: All thresholds met → k6 exits with code `0`
- **FAIL**: Any threshold breached → k6 exits with non-zero code

Thresholds:
- `http_req_duration['p(95)<50']` — p95 latency < 50ms
- `http_req_failed['rate<0.01']` — error rate < 1%

---

## 4. Configuration Parameters

All configurable via environment variables (no code changes required):

All vars use the `BENCHMARK_` prefix to avoid collisions with existing service vars in the root `.env.example`.

| Env var | Default | Description |
|---|---|---|
| `BENCHMARK_BASE_URL` | `http://producer:8080` | Producer app base URL |
| `BENCHMARK_SCENARIO` | `sustained` | Which scenario to run (`sustained`, `ramp-up`, `stress`) |
| `BENCHMARK_TARGET_RPS` | `500` | Target rate for sustained load scenario |
| `BENCHMARK_DURATION` | `120s` | Duration of sustained load phase |
| `BENCHMARK_PREALLOCATED_VUS` | `100` | VU pool pre-warmed for arrival-rate executors |
| `BENCHMARK_MAX_VUS` | `300` | Hard ceiling on VU count |
| `BENCHMARK_SETUP_USERS` | `200` | Users created during setup phase |
| `BENCHMARK_SETUP_VIDEOS` | `100` | Videos created during setup phase |
