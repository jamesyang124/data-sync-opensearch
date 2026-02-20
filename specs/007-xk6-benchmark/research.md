# Research: xk6 Benchmark Suite

**Phase**: 0 — Pre-Design Research
**Date**: 2026-02-20
**Feature**: 007-xk6-benchmark

---

## 1. xk6 Build Process

**Decision**: Use the official `grafana/xk6` Docker image via a multi-stage Dockerfile to produce a custom k6 binary with xk6-faker baked in.

**Rationale**: No local Go toolchain is required. The multi-stage build keeps the final runner image minimal (based on `grafana/k6:latest`) while the build stage handles the xk6 compilation.

**Pattern**:
```dockerfile
FROM golang:1.21 AS builder
RUN go install go.k6.io/xk6/cmd/xk6@latest
RUN xk6 build \
    --with github.com/grafana/xk6-faker \
    --output /k6

FROM grafana/k6:latest
COPY --from=builder /k6 /usr/bin/k6
```

**Alternatives considered**:
- Local `xk6 build` (rejected: requires Go toolchain on every developer machine)
- Pre-built binary committed to git (rejected: platform-specific, bloats repo)

---

## 2. xk6-faker Extension

**Decision**: Use `github.com/grafana/xk6-faker` (official Grafana extension). Import in k6 scripts as `k6/x/faker`.

**Key API surface for our schema**:

| Entity field | faker call |
|---|---|
| `username` | `` `${faker.person.firstName()}_${faker.person.lastName()}` `` |
| `email` | `faker.person.email()` |
| `video.title` | `faker.lorem.sentence(5)` |
| `video.description` | `faker.lorem.paragraph(1, 3, 10, ' ')` |
| `video.duration` | `faker.number.intRange(60, 7200)` |
| `comment.text` | `faker.lorem.paragraph(1, 2, 8, ' ')` |
| `user_id` / `video_id` | tracked in shared state (not generated fresh; looked up from pool) |

**Note on seeding**: The `Faker` class supports a seed for reproducible data (`new Faker(42)`). For load testing, the default non-seeded instance is preferred to maximize data variety and avoid duplicate-key collisions.

**Example script fragment**:
```javascript
import faker from 'k6/x/faker';

function buildUser() {
  return {
    username: `${faker.person.firstName()}_${faker.person.lastName()}_${Date.now()}`,
    email:    `${faker.string.uuid()}@example.com`,
  };
}
```

**Alternatives considered**:
- Manual random string generation (rejected: verbose, less realistic data)
- Static fixture files (rejected: would exhaust at high RPS, cause 409 Conflicts)

---

## 3. k6 Scenario Executors

**Decision summary**:

| Scenario | Executor | Why |
|---|---|---|
| Sustained load (500 RPS) | `constant-arrival-rate` | Open model; maintains fixed iteration rate regardless of response time |
| Ramp-up | `ramping-arrival-rate` | Open model with staged ramp; matches realistic traffic growth patterns |
| Stress test | `ramping-vus` | Closed model; progressively increases concurrency to find saturation point |

**Key insight**: `constant/ramping-arrival-rate` executors are **open models** — k6 starts a new iteration every `1/rate` seconds regardless of whether previous ones have finished. This accurately simulates real traffic and avoids the "coordinated omission" problem that closed-model (VU-based) tests suffer under load.

**Sustained load example** (target: 500 RPS):
```javascript
export const options = {
  scenarios: {
    sustained: {
      executor: 'constant-arrival-rate',
      duration: '120s',
      rate: 500,
      timeUnit: '1s',
      preAllocatedVUs: 100,
      maxVUs: 200,
    },
  },
};
```

**Ramp-up example** (0 → 500 RPS over 90s):
```javascript
stages: [
  { target: 50,  duration: '30s' },
  { target: 200, duration: '30s' },
  { target: 500, duration: '30s' },
  { target: 500, duration: '60s' },  // hold
  { target: 0,   duration: '15s' },  // cool down
],
```

**Stress test example** (push past 500 to find limit):
```javascript
stages: [
  { target: 50,   duration: '30s' },
  { target: 500,  duration: '60s' },
  { target: 1000, duration: '60s' },  // exceeds target
  { target: 1500, duration: '60s' },  // break point
  { target: 0,    duration: '20s' },
],
```

---

## 4. k6 Thresholds

**Decision**: Define thresholds in the shared config; each scenario inherits them. Use `abortOnFail: false` so the full test duration completes and all data points are collected even under failure conditions (enables post-mortem analysis).

**Threshold definitions**:
```javascript
export const thresholds = {
  http_req_duration: ['p(95)<50'],   // p95 < 50ms
  http_req_failed:   ['rate<0.01'],  // error rate < 1%
};
```

**Per-endpoint thresholds** (using tagged sub-metrics):
```javascript
'http_req_duration{endpoint:create_user}': ['p(95)<50'],
'http_req_duration{endpoint:create_video}': ['p(95)<50'],
```

**PASS/FAIL verdict**: When thresholds fail, k6 exits with a non-zero exit code — directly usable as a CI gate (Docker `--exit-code-from`).

---

## 5. k6 Output Formats

**Decision**: Emit both raw NDJSON (for time-series analysis) and an aggregated JSON summary (for CI reporting) using `handleSummary`.

**Command**:
```bash
k6 run --out json=reports/raw.ndjson script.js
```

**Summary export** (added to every script):
```javascript
import { textSummary } from 'https://jslib.k6.io/k6-summary/0.0.2/index.js';

export function handleSummary(data) {
  return {
    'reports/summary.json': JSON.stringify(data, null, 2),
    stdout: textSummary(data, { indent: ' ', enableColors: true }),
  };
}
```

**Report contents**: The `data` object in `handleSummary` contains all metrics with aggregated values: `avg`, `min`, `max`, `p(50)`, `p(95)`, `p(99)`, `count`, `rate`. This is the same table printed to the terminal, exportable to JSON for dashboards or CI artifact upload.

---

## 6. Producer App API Surface (Actual Implementation State)

Confirmed from reading `producer/` source code:

| Endpoint | Status | Request body |
|---|---|---|
| `POST /api/v1/users` | ✅ Implemented | `{ username, email }` |
| `PUT /api/v1/users/{id}` | ✅ Implemented | `{ username, email }` |
| `DELETE /api/v1/users/{id}` | ✅ Implemented | — |
| `POST /api/v1/videos` | ✅ Implemented | `{ user_id, title, description, duration }` |
| `PUT /api/v1/videos/{id}` | ⚠️ Not yet routed | — |
| `DELETE /api/v1/videos/{id}` | ⚠️ Not yet routed | — |
| `POST /api/v1/comments` | ⚠️ Not yet implemented | — |
| `PUT /api/v1/comments/{id}` | ⚠️ Not yet implemented | — |
| `DELETE /api/v1/comments/{id}` | ⚠️ Not yet implemented | — |
| `GET /health` | ✅ Implemented | — |

**Impact on benchmark design**: The benchmark will implement its workload against the currently available endpoints. Scripts will be written to accommodate future Comments endpoints when they are added (FR-001 of the producer spec requires them). The benchmark library will be structured so adding a comments scenario is a one-file addition.

---

## 7. Referential Integrity Strategy in k6

**Problem**: Videos reference a `user_id`; a video's CREATE requires a valid user to exist first. At high RPS across multiple VUs, user IDs cannot be safely stored in a simple variable.

**Decision**: Use a k6 `SharedArray` to hold a pre-seeded pool of user IDs (created in the `setup()` phase), and a per-iteration strategy of selecting a random ID from the pool for video creation. Video IDs are similarly tracked for comment creation.

**Pattern**:
```javascript
import { SharedArray } from 'k6/data';

// setup() runs once before all VUs start
export function setup() {
  const users = [];
  for (let i = 0; i < 100; i++) {
    const res = http.post(`${BASE_URL}/api/v1/users`, JSON.stringify(buildUser()));
    users.push(res.json('user_id'));
  }
  return { userIds: users };
}

export default function (data) {
  const userId = data.userIds[Math.floor(Math.random() * data.userIds.length)];
  // use userId in video/comment creation
}
```

**Alternatives considered**:
- Generate UUIDs client-side and pass them in both user create + video create (rejected: UUIDs would not be in DB unless user create succeeded — race condition risk)
- Shared global state between VUs (rejected: not thread-safe in k6's runtime model)
