# Benchmark Scenario Contracts

**Feature**: 007-xk6-benchmark
**Date**: 2026-02-20

These contracts define the observable guarantees of each benchmark scenario — what it exercises, what it measures, and what constitutes a passing result. They are technology-agnostic descriptions of the script behavior.

---

## Scenario 1: Sustained Load (`sustained-load`)

**Purpose**: Validate that the producer app meets its baseline throughput and latency targets under steady-state production-like traffic.

### Invocation

```bash
SCENARIO=sustained k6 run benchmark/scripts/main.js
# or: docker compose run benchmark --env SCENARIO=sustained
```

### Load Profile

| Phase | Duration | Rate |
|---|---|---|
| Warm-up | 10s | 50 RPS |
| Sustained | 120s | 500 RPS |
| Cool-down | 10s | 0 RPS |

### Operations Exercised

| Operation | Endpoint | Weight |
|---|---|---|
| Create User | `POST /api/v1/users` | 40% |
| Update User | `PUT /api/v1/users/{id}` | 20% |
| Delete User | `DELETE /api/v1/users/{id}` | 10% |
| Create Video | `POST /api/v1/videos` | 30% |

### Pass Criteria

| Threshold | Metric | Condition |
|---|---|---|
| Latency | p95 of all `http_req_duration` | `< 50ms` |
| Error rate | `http_req_failed` rate | `< 1%` |
| Throughput | Measured RPS at peak | `≥ 480 RPS` (within 4% of 500) |

### Expected Output

- `reports/sustained-summary.json` — aggregated metrics
- `reports/sustained-raw.ndjson` — per-sample time series
- Terminal: PASS or FAIL verdict with threshold table

---

## Scenario 2: Ramp-Up (`ramp-up`)

**Purpose**: Observe latency and error-rate behavior as load grows from zero to target, revealing warm-up effects and saturation onset.

### Invocation

```bash
SCENARIO=ramp-up k6 run benchmark/scripts/main.js
```

### Load Profile

| Phase | Duration | Rate |
|---|---|---|
| Stage 1 | 30s | 0 → 50 RPS |
| Stage 2 | 30s | 50 → 200 RPS |
| Stage 3 | 30s | 200 → 500 RPS |
| Hold | 60s | 500 RPS |
| Cool-down | 15s | 500 → 0 RPS |

### Operations Exercised

Same distribution as Sustained Load scenario.

### Pass Criteria

| Threshold | Metric | Condition |
|---|---|---|
| Latency at hold | p95 during hold phase | `< 50ms` |
| Error rate | Overall `http_req_failed` rate | `< 1%` |

### Expected Output

- `reports/ramp-summary.json`
- `reports/ramp-raw.ndjson`
- Terminal: Stage-by-stage RPS observations visible in time-series NDJSON

---

## Scenario 3: Stress Test (`stress`)

**Purpose**: Deliberately exceed the target load to identify the saturation point and validate graceful degradation (503 backpressure, no crashes).

### Invocation

```bash
SCENARIO=stress k6 run benchmark/scripts/main.js
```

### Load Profile

| Phase | Duration | Concurrent VUs |
|---|---|---|
| Ramp | 30s | 0 → 50 |
| Normal | 60s | 50 (≈ 500 RPS) |
| Stress | 60s | 200 (≈ 1000 RPS) |
| Peak | 60s | 400 (≈ 2000 RPS) |
| Cool-down | 20s | 0 |

*Note: Stress uses `ramping-vus` (closed model) intentionally — VU count is the control variable, not RPS.*

### Operations Exercised

Same distribution as Sustained Load scenario.

### Pass Criteria (modified for stress context)

| Observation | Metric | Expected |
|---|---|---|
| Breaking point identified | RPS at which error rate crosses 5% | Documented in report |
| Graceful degradation | HTTP status codes under overload | 503 observed (not 500/crash) |
| Recovery | Error rate after cool-down | Returns to `< 1%` |

*Note: The stress scenario intentionally breaches the standard thresholds. The k6 exit code will be non-zero; this is expected and does not indicate a benchmark configuration error.*

### Expected Output

- `reports/stress-summary.json`
- `reports/stress-raw.ndjson`
- Terminal: Breaking point RPS annotated in summary

---

## Health Check Contract

**Pre-flight check** (runs before every scenario):

```
GET /health
Expected response: HTTP 200 with body indicating all components healthy
Failure behavior: Abort with error "Producer app not healthy — aborting benchmark"
```

---

## Tagging Contract

Every HTTP request in all scenarios MUST include the `endpoint` tag to enable per-endpoint sub-metric filtering in reports:

```javascript
http.post(url, body, { tags: { endpoint: 'create_user' } });
http.put(url, body, { tags: { endpoint: 'update_user' } });
http.del(url, { tags: { endpoint: 'delete_user' } });
http.post(url, body, { tags: { endpoint: 'create_video' } });
```

This enables threshold queries like `http_req_duration{endpoint:create_user}` in Grafana or post-processing scripts.
