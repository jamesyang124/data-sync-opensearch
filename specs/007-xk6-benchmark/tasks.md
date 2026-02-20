---

description: "Task list for xk6 Benchmark Suite implementation"
---

# Tasks: xk6 Benchmark Suite for Producer App

**Input**: Design documents from `/specs/007-xk6-benchmark/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/benchmark-scenarios.md ✅, quickstart.md ✅

**Tests**: No test tasks generated — k6 thresholds and the health-check preflight are the validation mechanism; no separate test framework requested in spec.

**Organization**: Tasks grouped by user story (US1 → US2 → US3) to enable independent implementation, testing, and delivery of each scenario.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no shared dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Exact file paths included in every description

## Path Conventions

Per `plan.md` — source lives under `benchmark/` at repo root alongside `producer/`, `consumer/`, etc. Root files (`docker-compose.yml`, `.env.example`, `.gitignore`) are modified in place.

```text
benchmark/
├── Dockerfile
├── Makefile
├── reports/           ← git-ignored
└── scripts/
    ├── main.js
    ├── lib/
    │   ├── faker.js
    │   ├── client.js
    │   └── thresholds.js
    └── scenarios/
        ├── sustained-load.js
        ├── ramp-up.js
        └── stress.js
```

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the benchmark service directory skeleton and build tooling before any script work begins.

- [ ] T001 Create `benchmark/` directory structure: `benchmark/scripts/lib/`, `benchmark/scripts/scenarios/`, `benchmark/reports/`; add `benchmark/reports/` to root `.gitignore`
- [ ] T002 [P] Create `benchmark/Dockerfile` with multi-stage xk6 build — Stage 1: `FROM grafana/xk6` runs `xk6 build --with github.com/grafana/xk6-faker@latest --output /k6`; Stage 2: `FROM grafana/k6:latest` copies binary to `/usr/bin/k6`
- [ ] T003 [P] Create `benchmark/Makefile` with targets: `build` (docker build, tag `data-sync/benchmark:latest`), `run-sustained`, `run-ramp`, `run-stress` (each runs `docker compose --profile benchmark run --rm benchmark` from repo root with the correct `BENCHMARK_SCENARIO` env value), `clean` (delete `benchmark/reports/*.json` and `*.ndjson`)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared library modules and Docker Compose wiring that ALL scenario scripts depend on. No scenario script can be written until this phase is complete.

**⚠️ CRITICAL**: No user-story scenario work can begin until this phase is complete.

- [ ] T004 [P] Add `benchmark` service block to root `docker-compose.yml` — `profiles: ["benchmark"]`, image `data-sync/benchmark:latest`, entrypoint `k6 run /scripts/main.js --out json=/reports/raw.ndjson`, bind-mounts `./benchmark/scripts:/scripts` and `./benchmark/reports:/reports`, env vars sourced from root `.env`, `depends_on: producer`
- [ ] T005 [P] Append `BENCHMARK_*` variable block to root `.env.example` alongside existing service vars: `BENCHMARK_BASE_URL=http://producer:8080`, `BENCHMARK_SCENARIO=sustained`, `BENCHMARK_TARGET_RPS=500`, `BENCHMARK_DURATION=120s`, `BENCHMARK_PREALLOCATED_VUS=100`, `BENCHMARK_MAX_VUS=300`, `BENCHMARK_SETUP_USERS=200`, `BENCHMARK_SETUP_VIDEOS=100`
- [ ] T006 [P] Create `benchmark/scripts/lib/faker.js` — export `buildUser()` returning `{ username: \`${faker.person.firstName()}_${faker.person.lastName()}_${Date.now()}\`, email: \`${faker.string.uuid()}@example.com\` }`; export `buildVideo(userId)` returning `{ user_id, title: faker.lorem.sentence(5), description: faker.lorem.paragraph(1,3,10,' '), duration: faker.number.intRange(60,7200) }`; export `buildComment(videoId, userId)` as a placeholder returning `{ video_id, user_id, comment_text: faker.lorem.sentence(15) }` (no active requests until Comments endpoint ships); import faker from `k6/x/faker`
- [ ] T007 [P] Create `benchmark/scripts/lib/thresholds.js` — export `thresholds` object: `{ 'http_req_duration': ['p(95)<50'], 'http_req_failed': ['rate<0.01'], 'http_req_duration{endpoint:create_user}': ['p(95)<50'], 'http_req_duration{endpoint:update_user}': ['p(95)<50'], 'http_req_duration{endpoint:delete_user}': ['p(95)<50'], 'http_req_duration{endpoint:create_video}': ['p(95)<50'] }`
- [ ] T008 Create `benchmark/scripts/lib/client.js` — export `createUser(baseUrl)`, `updateUser(baseUrl, userId)`, `deleteUser(baseUrl, userId)`, `createVideo(baseUrl, userId)` HTTP helpers using `http.post/put/del` with `Content-Type: application/json` header and `tags: { endpoint: '<name>' }` per tagging contract; handle 409 Conflict and 503 as expected events tracked via separate `Counter` metrics, not test failures; export `runWorkload(baseUrl, userIds, videoIds)` shared CRUD dispatch (40% createUser, 20% updateUser, 10% deleteUser, 30% createVideo) (depends on T006)
- [ ] T009 Create `benchmark/scripts/main.js` — read `__ENV.BENCHMARK_SCENARIO`; perform pre-flight `GET ${BENCHMARK_BASE_URL}/health` and abort with `"Producer app not healthy — aborting benchmark"` if response is not HTTP 200; route to the correct scenario using **static imports at the top of the file** (`import * as sustained from './scenarios/sustained-load.js'` etc.) and a `switch (__ENV.BENCHMARK_SCENARIO)` dispatch — **do not use dynamic `import()` expressions**, which are not supported in k6's Goja ES6 runtime; throw a descriptive error on unknown SCENARIO value (depends on T006, T007, T008; note: static imports require scenario files to exist before main.js is runnable — individual scenarios can be run directly via `k6 run benchmark/scripts/scenarios/<name>.js` until all three exist)

**Checkpoint**: Shared library complete — all three scenario scripts can now be implemented independently and in parallel.

---

## Phase 3: User Story 1 — Sustained Load Benchmark (Priority: P1) 🎯 MVP

**Goal**: A single `make -C benchmark run-sustained` command runs a 500 RPS steady-state load test against the producer app, produces a PASS/FAIL verdict, and writes machine-readable reports.

**Independent Test**: `BENCHMARK_TARGET_RPS=20 BENCHMARK_DURATION=15s make -C benchmark run-sustained` completes without error, writes `benchmark/reports/sustained-summary.json` with `http_req_duration` and `http_req_failed` threshold results, and exits with code 0 on PASS.

### Implementation for User Story 1

- [ ] T010 [US1] Create `benchmark/scripts/scenarios/sustained-load.js` — import `thresholds` from lib/thresholds.js, `buildUser`/`buildVideo` from lib/faker.js, `createUser`/`createVideo`/`runWorkload` from lib/client.js; export `const options` with **`ramping-arrival-rate`** executor matching the benchmark-scenarios.md contract: `startRate: 50`, `timeUnit: '1s'`, `preAllocatedVUs: parseInt(__ENV.BENCHMARK_PREALLOCATED_VUS, 10)`, `maxVUs: parseInt(__ENV.BENCHMARK_MAX_VUS, 10)`, stages `[{target:50,duration:'10s'},{target:parseInt(__ENV.BENCHMARK_TARGET_RPS,10),duration:'1s'},{target:parseInt(__ENV.BENCHMARK_TARGET_RPS,10),duration:__ENV.BENCHMARK_DURATION},{target:0,duration:'10s'}]` (10s warm-up hold at 50 RPS → step to target RPS → sustained hold → 10s cool-down ramp to 0), plus `thresholds`
- [ ] T011 [US1] Implement `export function setup()` in `benchmark/scripts/scenarios/sustained-load.js` — create `BENCHMARK_SETUP_USERS` users via `createUser()` collecting returned user IDs; create `BENCHMARK_SETUP_VIDEOS` videos via `createVideo()` using random user IDs; abort with clear error if fewer than 10 users or 5 videos were successfully seeded (pool minimum guard per spec edge case); return `{ userIds, videoIds }`
- [ ] T012 [US1] Implement `export default function(data)` in `benchmark/scripts/scenarios/sustained-load.js` — call `runWorkload(BASE_URL, data.userIds, data.videoIds)` from lib/client.js; use `check()` to assert 2xx responses; 404 on DELETE and 409/503 are handled inside client.js as expected events
- [ ] T013 [US1] Implement `export function handleSummary(data)` in `benchmark/scripts/scenarios/sustained-load.js` — return `{ 'reports/sustained-summary.json': JSON.stringify(data, null, 2), stdout: textSummary(data, { indent: ' ', enableColors: true }) }`; import `textSummary` from `https://jslib.k6.io/k6-summary/0.0.2/index.js`

**Checkpoint**: User Story 1 fully functional — `make -C benchmark run-sustained` emits PASS/FAIL verdict in terminal and writes `reports/sustained-summary.json`.

---

## Phase 4: User Story 2 — Configurable Ramp-Up Scenario (Priority: P2)

**Goal**: `make -C benchmark run-ramp` runs a staged load ramp from 0 to 500 RPS, capturing per-stage behavior in metrics.

**Independent Test**: `BENCHMARK_SCENARIO=ramp-up make -C benchmark run-ramp` completes all stages, writes `benchmark/reports/ramp-summary.json` and `benchmark/reports/ramp-raw.ndjson`, and shows stage-by-stage throughput changes in the terminal summary.

### Implementation for User Story 2

- [ ] T014 [US2] Create `benchmark/scripts/scenarios/ramp-up.js` — same imports as sustained-load.js; export `const options` with `ramping-arrival-rate` executor: `startRate: 0`, `timeUnit: '1s'`, `preAllocatedVUs: 100`, `maxVUs: __ENV.BENCHMARK_MAX_VUS`, stages `[{target:50,duration:'30s'},{target:200,duration:'30s'},{target:500,duration:'30s'},{target:500,duration:'60s'},{target:0,duration:'15s'}]`; include `thresholds`
- [ ] T015 [US2] Implement `export function setup()` and `export default function(data)` in `benchmark/scripts/scenarios/ramp-up.js` — replicate setup() pool seeding logic from sustained-load.js (k6 requires `setup()` to be a named export in each scenario file; it cannot be imported); **include the minimum pool guard: abort with a clear error if fewer than 10 users or 5 videos were successfully seeded**; call `runWorkload()` from `benchmark/scripts/lib/client.js` in the default function
- [ ] T016 [US2] Implement `export function handleSummary(data)` in `benchmark/scripts/scenarios/ramp-up.js` — write `reports/ramp-summary.json` and emit stdout table (same textSummary pattern as sustained-load.js)

**Checkpoint**: User Story 2 functional — ramp-up scenario independently runnable alongside sustained-load.

---

## Phase 5: User Story 3 — Stress / Spike Test (Priority: P3)

**Goal**: `make -C benchmark run-stress` drives load past 1000 RPS using `ramping-vus`, captures the breaking point (RPS at which error rate first exceeds 5%), and always exits with code 0 regardless of threshold breaches.

**Independent Test**: `BENCHMARK_SCENARIO=stress make -C benchmark run-stress` completes all VU stages (does not abort early at threshold breach), writes `benchmark/reports/stress-summary.json` containing a `breaking_point_rps` annotation, and exits with code 0.

### Implementation for User Story 3

- [ ] T017 [US3] Create `benchmark/scripts/scenarios/stress.js` — same imports as sustained-load.js; export `const options` with `ramping-vus` executor: `startVUs: 0`, stages `[{target:50,duration:'30s'},{target:200,duration:'60s'},{target:400,duration:'60s'},{target:0,duration:'20s'}]`; override `thresholds` from lib/thresholds.js with `abortOnFail: false` on all entries so full duration always completes
- [ ] T018 [US3] Implement `export function setup()` and `export default function(data)` in `benchmark/scripts/scenarios/stress.js` — replicate setup() pool seeding from sustained-load.js; **include the minimum pool guard: abort with a clear error if fewer than 10 users or 5 videos were seeded**; call `runWorkload()` from lib/client.js in the default function; add a dedicated `Counter` metric `backpressure_503_total` to track 503 responses separately from failures
- [ ] T019 [US3] Implement `export function handleSummary(data)` in `benchmark/scripts/scenarios/stress.js` — write `reports/stress-summary.json` (standard aggregated metrics only; `handleSummary` receives totals, not per-second buckets); **breaking-point detection is a post-processing step, not inside handleSummary**: add a `jq` pipeline in the `run-stress` Makefile target that filters `benchmark/reports/stress-raw.ndjson` for the first time sample where `http_req_failed.rate > 0.05` and appends `breaking_point_rps` to `stress-summary.json` after k6 exits; emit human-readable summary to stdout via `textSummary`; stress scenario exits 0 via `abortOnFail: false` on all thresholds

**Checkpoint**: All three user stories independently executable — each `make -C benchmark run-*` target works end-to-end.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: End-to-end smoke validation and documentation.

- [ ] T020 [P] Write `benchmark/README.md` — prerequisites (Docker, producer running), build command, per-scenario invocation table, configuration variable reference (all `BENCHMARK_*` vars with defaults), report file locations, troubleshooting section (matches quickstart.md)
- [ ] T021 Run full quickstart.md smoke validation: `docker compose up -d`, verify `/health` returns 200, then `BENCHMARK_TARGET_RPS=20 BENCHMARK_DURATION=15s make -C benchmark run-sustained`; confirm `reports/sustained-summary.json` is written and exit code is 0
- [ ] T022 [P] Verify `make -C benchmark build` produces a working xk6 image by running `docker run --rm data-sync/benchmark:latest version` and confirming k6 version output includes the `xk6-faker` extension in the modules list

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 complete — **BLOCKS all scenario work**
- **US1 (Phase 3)**: Unblocked after Phase 2 — no dependency on US2 or US3
- **US2 (Phase 4)**: Unblocked after Phase 2 — no dependency on US1 or US3
- **US3 (Phase 5)**: Unblocked after Phase 2 — no dependency on US1 or US2
- **Polish (Phase 6)**: Depends on desired user stories being complete

### User Story Dependencies

- **US1 (P1)**: Independently testable after Phase 2 — run `k6 run benchmark/scripts/scenarios/sustained-load.js` directly
- **US2 (P2)**: Independently testable after Phase 2 — shares `runWorkload()` helper from T008
- **US3 (P3)**: Independently testable after Phase 2 — shares `runWorkload()` helper from T008

### Within Each User Story

- Scaffold `options` export → `setup()` → `default function` → `handleSummary()`
- Each step has an in-story sequential dependency on the previous

### Parallel Opportunities

- T002, T003 (Phase 1): Dockerfile and Makefile are different files — run in parallel after T001
- T004, T005, T006, T007 (Phase 2): all target different files with no mutual dependencies — run in parallel
- T008 (client.js): starts after T006 (faker.js) is complete
- T009 (main.js): starts after T006, T007, T008 are complete
- T010–T013 (US1), T014–T016 (US2), T017–T019 (US3): entirely separate scenario files — all can run in parallel once Phase 2 is complete
- T020, T022 (Polish): different targets, run in parallel

---

## Parallel Example: Foundational Phase

```text
# T004, T005, T006, T007 can all start immediately (different files, no mutual deps):
Task A: T004 — Add benchmark service to docker-compose.yml
Task B: T005 — Append BENCHMARK_* vars to .env.example
Task C: T006 — Create benchmark/scripts/lib/faker.js
Task D: T007 — Create benchmark/scripts/lib/thresholds.js

# T008 starts after T006 (client.js imports faker.js):
Task E: T008 — Create benchmark/scripts/lib/client.js

# T009 starts after T006 + T007 + T008 (main.js imports all lib modules):
Task F: T009 — Create benchmark/scripts/main.js
```

## Parallel Example: User Stories (Once Phase 2 Complete)

```text
Developer A: T010 → T011 → T012 → T013   (sustained-load.js — US1)
Developer B: T014 → T015 → T016          (ramp-up.js — US2)
Developer C: T017 → T018 → T019          (stress.js — US3)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup — directory structure, Dockerfile, Makefile
2. Complete Phase 2: Foundational — faker.js, thresholds.js, client.js, main.js, compose/env wiring (**critical blocker**)
3. Complete Phase 3: US1 — sustained-load.js (T010–T013)
4. **STOP and VALIDATE**: `BENCHMARK_TARGET_RPS=20 BENCHMARK_DURATION=15s make -C benchmark run-sustained`
5. Confirm `reports/sustained-summary.json` written with PASS verdict

### Incremental Delivery

1. Phase 1 + Phase 2 → library and build tooling ready
2. US1 (sustained-load.js) → sustained 500 RPS benchmark with PASS/FAIL verdict (**MVP** ✅)
3. US2 (ramp-up.js) → ramp-up profile with stage-by-stage data
4. US3 (stress.js) → saturation/breaking-point detection
5. Polish → README + smoke validation

---

## Notes

- `[P]` tasks touch different files with no mutual dependencies
- `[Story]` label maps each task to the user story it makes independently testable
- `runWorkload()` helper in `benchmark/scripts/lib/client.js` (T008) is the single source of truth for the 40/20/10/30 CRUD mix — ramp-up and stress scenarios import it, never duplicate it
- `reports/` is git-ignored; CI must archive reports as build artifacts explicitly
- Comments scenario is a placeholder in `faker.js` only (buildComment); no active scenario script until the producer Comments endpoint ships
- Pool exhaustion (404 on DELETE) is expected: client.js tracks these separately, does not count as test failures
- Stress scenario: `abortOnFail: false` on all thresholds is the mechanism ensuring code 0 exit regardless of threshold breaches per FR-008 and the session clarification
- main.js (T009) uses static imports — it can be written in Phase 2 but is only runnable once all three scenario files exist; individual scenarios remain independently testable via direct `k6 run` until then
