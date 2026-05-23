# Benchmark Suite — xk6 + xk6-faker

Load-testing suite for the producer app REST API.
Uses [k6](https://k6.io) with the [xk6-faker](https://github.com/grafana/xk6-faker) extension for realistic fake data generation.

---

## Prerequisites

- Docker and Docker Compose
- Producer app running (`docker compose up -d`)
- `jq` installed (required for `run-stress` breaking-point annotation only)

---

## Quick Start

```bash
# 1. Build the custom k6 image with xk6-faker baked in (one-time)
make -C benchmark build

# 2. Run the sustained-load scenario (500 RPS / 120s — primary benchmark)
#    This automatically starts the full stack (postgres, kafka, connect,
#    opensearch, producer) and waits for the producer to be healthy first.
make -C benchmark run-sustained

# 3. View the results
cat benchmark/reports/sustained-summary.json | jq '.metrics.http_req_duration'
```

---

## Scenarios

| Scenario | Make Target | Executor | Profile |
|---|---|---|---|
| Sustained Load | `run-sustained` | ramping-arrival-rate | 10s warm-up → 120s @ 500 RPS → 10s cool-down |
| Ramp-Up | `run-ramp` | ramping-arrival-rate | 0→50→200→500 RPS over 90s, 60s hold, 15s ramp-down |
| Stress Test | `run-stress` | ramping-vus | 0→50→200→400 VU over 170s, finds saturation point |

All scenarios exercise the same CRUD workload mix against the producer API:

| Operation | Endpoint | Weight |
|---|---|---|
| Create User | `POST /api/v1/users` | 25% |
| Update User | `PUT /api/v1/users/{id}` | 10% |
| Delete User | `DELETE /api/v1/users/{id}` | 5% |
| Create Video | `POST /api/v1/videos` | 20% |
| Update Video | `PUT /api/v1/videos/{id}` | 10% |
| Delete Video | `DELETE /api/v1/videos/{id}` | 5% |
| Create Comment | `POST /api/v1/comments` | 10% |
| Update Comment | `PUT /api/v1/comments/{id}` | 10% |
| Delete Comment | `DELETE /api/v1/comments/{id}` | 5% |

**These weights are fixed in code (`benchmark/scripts/lib/client.js`) and are not configurable via env vars.**

---

## Configuration

All vars use the `BENCHMARK_` prefix. Set in the root `.env` file or pass inline:

| Variable | Default | Description |
|---|---|---|
| `BENCHMARK_BASE_URL` | `http://producer:8080` | Producer app URL (on Docker network) |
| `BENCHMARK_SCENARIO` | `sustained` | Scenario to run (`sustained`, `ramp-up`, `stress`) |
| `BENCHMARK_TARGET_RPS` | `500` | Target RPS for sustained-load scenario |
| `BENCHMARK_DURATION` | `120s` | Duration of sustained-load hold phase |
| `BENCHMARK_PREALLOCATED_VUS` | `100` | Pre-warmed VU pool for arrival-rate executors |
| `BENCHMARK_MAX_VUS` | `300` | Hard VU ceiling |
| `BENCHMARK_SETUP_USERS` | `200` | Users seeded in setup() before test starts |
| `BENCHMARK_SETUP_VIDEOS` | `100` | Videos seeded in setup() before test starts |
| `BENCHMARK_SETUP_COMMENTS` | `100` | Comments seeded in setup() before test starts |

Example — quick smoke check at 20 RPS for 30s:

```bash
BENCHMARK_TARGET_RPS=20 BENCHMARK_DURATION=30s make -C benchmark run-sustained
```

---

## Reports

Reports are written to `benchmark/reports/` (git-ignored). CI should archive them as build artifacts.

| File | Scenario | Contents |
|---|---|---|
| `sustained-summary.json` | Sustained | Aggregated metrics + PASS/FAIL thresholds |
| `sustained-raw.ndjson` | Sustained | Per-sample time series |
| `ramp-summary.json` | Ramp-Up | Aggregated metrics |
| `ramp-raw.ndjson` | Ramp-Up | Per-sample time series |
| `stress-summary.json` | Stress | Aggregated metrics + `breaking_point_rps` annotation |
| `stress-raw.ndjson` | Stress | Per-sample time series |

### Pass/Fail Thresholds

| Metric | Threshold | Applies to |
|---|---|---|
| `http_req_duration` p95 | < 50ms | Sustained, Ramp-Up |
| `http_req_failed` rate | < 1% | Sustained, Ramp-Up |
| Per-endpoint p95 | < 50ms | Sustained, Ramp-Up |

The stress scenario captures threshold data but **always exits with code 0** (threshold breaches are expected and for human review only).

---

## CI Integration

```bash
# Run sustained benchmark and gate CI on PASS/FAIL
make -C benchmark run-sustained
if [ $? -ne 0 ]; then
  echo "Benchmark FAILED — p95 or error rate threshold breached"
  exit 1
fi

# Archive reports (GitHub Actions example)
# - uses: actions/upload-artifact@v4
#   with:
#     name: benchmark-reports
#     path: benchmark/reports/
```

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Producer app not healthy — aborting` | Producer not running | `docker compose up -d producer` |
| `Pool seeding failed: seeded 0 users` | Producer unreachable or DB down | Check `docker compose ps` and `GET /health` |
| High 409 error rate at startup | Duplicate key from prior run (rare) | Timestamp/UUID strategy prevents this; check logs |
| `jq: command not found` (run-stress) | jq not installed | `brew install jq` or `apt-get install jq` |
| `Binary not found in image` | Image not built | Run `make -C benchmark build` first |

---

## Architecture Notes

- **Fake data uniqueness**: generated `channel_id`, `video_id`, and future `comment_id` values use UUID prefixes; channel names include timestamp suffixes.
- **Referential integrity**: `setup()` pre-seeds 200 users + 100 videos into SharedArray pools. VUs draw random IDs from these pools per iteration.
- **404 on DELETE**: Expected — deleted users remain in the pool array. 404s are tracked separately and do not count toward the error rate.
- **409 on CREATE**: Tracked via `http_409_conflict_total` Counter, excluded from `http_req_failed`.
- **Breaking-point detection**: The `run-stress` Makefile target runs `jq` post-processing on `stress-raw.ndjson` to find the first time window where `http_req_failed.rate > 0.05` and annotates `stress-summary.json` with `breaking_point_rps`.
