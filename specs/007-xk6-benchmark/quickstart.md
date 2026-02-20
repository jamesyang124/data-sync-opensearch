# Quickstart: xk6 Benchmark Suite

**Feature**: 007-xk6-benchmark

---

## Prerequisites

- Docker and Docker Compose installed
- Producer app running (feature 006-producer-app)
- Producer app accessible at `http://localhost:8080` (default) or via Docker network

---

## 1. Build the xk6 Binary (First Time Only)

The benchmark suite ships as a Docker image with the custom k6 binary pre-built via xk6.

```bash
# Build the benchmark Docker image (includes xk6-faker extension)
make -C benchmark build
```

This compiles a `k6` binary with `xk6-faker` baked in using a multi-stage Docker build. The resulting image is tagged `data-sync/benchmark:latest`.

---

## 2. Start the Full Stack

```bash
# Start all components: postgres, kafka, debezium (connect), opensearch, producer
docker compose up -d

# Verify producer is healthy before benchmarking
curl http://localhost:8082/health
```

---

## 3. Run a Benchmark Scenario

The `benchmark` service uses a Docker Compose profile so it doesn't start with the default stack.

### Sustained Load (primary scenario — 500 RPS for 120s)

```bash
make -C benchmark run-sustained
# or directly from repo root:
docker compose --profile benchmark run --rm benchmark
```

### Ramp-Up

```bash
make -C benchmark run-ramp
```

### Stress Test

```bash
make -C benchmark run-stress
```

---

## 4. Read the Results

After each run, reports are written to `benchmark/reports/`:

```
benchmark/reports/
├── sustained-summary.json   # aggregated metrics (CI-friendly)
├── sustained-raw.ndjson     # per-sample time series
├── ramp-summary.json
└── stress-summary.json
```

The terminal output shows the k6 summary table and a PASS/FAIL verdict:

```
✓ http_req_duration.....: avg=18ms  p(95)=42ms  ✓ p(95)<50
✓ http_req_failed.......: 0.12%     ✓ rate<0.01

PASS — all thresholds met
```

---

## 5. Configuration

Benchmark vars live in the root `.env` file (alongside existing service vars) using the `BENCHMARK_` prefix. Override via `.env` or environment — no code changes needed:

| Variable | Default | Description |
|---|---|---|
| `BENCHMARK_BASE_URL` | `http://producer:8080` | Producer app URL |
| `BENCHMARK_SCENARIO` | `sustained` | Which scenario to run |
| `BENCHMARK_TARGET_RPS` | `500` | Sustained load target |
| `BENCHMARK_DURATION` | `120s` | Duration of sustained phase |
| `BENCHMARK_MAX_VUS` | `300` | Hard VU ceiling |
| `BENCHMARK_SETUP_USERS` | `200` | Users seeded before test |
| `BENCHMARK_SETUP_VIDEOS` | `100` | Videos seeded before test |

Example — run at 200 RPS for a quick smoke check (set in `.env` or inline):

```bash
BENCHMARK_TARGET_RPS=200 BENCHMARK_DURATION=30s \
  docker compose --profile benchmark run --rm benchmark
```

---

## 6. CI Integration

The benchmark exits with code `0` on PASS and non-zero on FAIL. Use `--exit-code-from` in Docker Compose or check `$?` after the run:

```bash
make -C benchmark run-sustained
if [ $? -ne 0 ]; then echo "Benchmark FAILED"; exit 1; fi
```

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Producer app not healthy — aborting` | Producer not started | `docker compose up -d producer` |
| `ERRO[0000] Request Failed (status: 409)` | Duplicate key from previous run | `make -C benchmark reset-db` or use `SETUP_USERS` pool rotation |
| High error rate at startup | VU pool not pre-warmed | Increase `SETUP_USERS` or add a longer warm-up stage |
| Binary not found in image | Image not built | Run `make -C benchmark build` first |
