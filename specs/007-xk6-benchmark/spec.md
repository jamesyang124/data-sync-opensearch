# Feature Specification: xk6 Benchmark Suite for Producer App

**Feature Branch**: `007-xk6-benchmark`
**Created**: 2026-02-20
**Status**: Draft
**Input**: User description: "now lets have benchmark tools using xk6 and its xk6 faker to pump producer app"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Sustained Load Benchmark (Priority: P1)

As a QA engineer, I need to run a sustained load test against the producer app REST API using realistically generated fake data, so I can verify the end-to-end CDC pipeline holds up under production-like traffic volumes.

**Why this priority**: This is the primary validation scenario — confirming that the producer app and downstream CDC pipeline can absorb target throughput without degradation. All other scenarios build on this foundation.

**Independent Test**: Can be fully tested by running the benchmark script against a live producer app and observing throughput and latency reports that confirm or deny the 500 RPS / p95 < 50ms target.

**Acceptance Scenarios**:

1. **Given** the producer app is running and healthy, **When** I run the load benchmark targeting 500 requests/second for a sustained period, **Then** the tool reports per-endpoint throughput, p50/p95/p99 latency, and error rate without crashing.
2. **Given** the benchmark is running, **When** it generates CREATE, UPDATE, and DELETE requests, **Then** each request uses realistic fake data (names, emails, video titles, comment text) consistent with the database schema.
3. **Given** the benchmark completes, **When** I inspect the summary report, **Then** I can see pass/fail status against the defined thresholds (500 RPS, p95 < 50ms, error rate < 1%).

---

### User Story 2 - Configurable Ramp-Up Scenario (Priority: P2)

As a QA engineer, I need a ramp-up load profile that gradually increases request volume from zero to the target rate, so I can observe how the producer app and CDC pipeline respond to growing load and identify the saturation point.

**Why this priority**: Ramp-up testing reveals capacity limits and enables tuning before committing to sustained full load. It also avoids cold-start spikes that skew results.

**Independent Test**: Run the ramp-up benchmark and confirm the tool reports throughput at each stage, with a clear transition from warm-up to full load visible in the output.

**Acceptance Scenarios**:

1. **Given** a ramp-up profile is configured, **When** the benchmark runs, **Then** virtual users increase in stages (e.g., 0 → 50 → 200 → 500 RPS) with configurable step duration.
2. **Given** the ramp-up reaches the target rate, **When** the system sustains it, **Then** the tool records latency and error metrics at each stage separately for comparison.

---

### User Story 3 - Stress / Spike Test (Priority: P3)

As a QA engineer, I need a stress test scenario that deliberately exceeds the target load, so I can identify the breaking point of the producer app and validate its backpressure behavior (e.g., 503 responses under overload).

**Why this priority**: Knowing the failure mode under extreme load (graceful degradation vs. crash) is important for operational readiness, but it is secondary to validating normal-load behavior.

**Independent Test**: Run the stress test and verify the tool reports the inflection point where error rates exceed acceptable thresholds, and that the app returns structured error responses rather than hanging or crashing.

**Acceptance Scenarios**:

1. **Given** the stress scenario is configured to exceed 1000 RPS, **When** the producer app saturates, **Then** the tool captures the point at which error rate first exceeds 5% and records the corresponding throughput.
2. **Given** the producer app starts returning 503 responses under overload, **When** the benchmark receives them, **Then** those responses are counted separately as expected backpressure events, not test failures.

---

### Edge Cases

- What happens when the producer app is unreachable at benchmark start? The tool must fail fast with a clear error rather than running a meaningless test.
- What if pool seeding partially fails during setup? The benchmark MUST proceed if at least 10 users and 5 videos are successfully seeded; if either minimum is not met, the benchmark MUST abort with a clear error indicating the pool size achieved vs. required.
- How does the tool handle partial failures mid-run (e.g., DB restart)? Metrics should still be captured up to the point of failure so results are usable.
- What if fake data generation produces a constraint violation (e.g., duplicate email)? The tool must treat 409 Conflict as an expected event and track it separately rather than aborting.
- What if a referenced parent entity (e.g., user for a comment) was already deleted? The benchmark must maintain referential integrity in its data generation sequence.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The benchmark suite MUST support at least three named scenarios: sustained load, ramp-up, and stress test, each selectable at invocation time.
- **FR-002**: The benchmark MUST generate realistic fake data for currently available entity types (Users, Videos) using a faker extension, covering all required fields per entity. Comment data builders MUST be scaffolded as placeholders for future activation.
- **FR-003**: The benchmark MUST include a fixed CRUD workload mix across available endpoints: 40% User CREATE, 20% User UPDATE, 10% User DELETE, 30% Video CREATE. These weights are not user-configurable; they are documented in the README. Video UPDATE/DELETE and Comment operations are deferred until those producer endpoints ship.
- **FR-004**: The benchmark MUST maintain referential integrity in its data generation — Comments reference valid Video IDs, Videos reference valid User IDs.
- **FR-005**: The benchmark MUST collect and report per-endpoint metrics: request count, throughput (RPS), latency percentiles (p50, p95, p99), and HTTP error counts by status code.
- **FR-006**: The benchmark MUST support configurable target RPS, test duration, and virtual user count via environment variables or a configuration file, without code changes.
- **FR-007**: The benchmark MUST perform a health check against the producer app's `/health` endpoint before starting the main test and abort if the service is unhealthy.
- **FR-008**: The benchmark MUST define pass/fail thresholds (error rate < 1%, p95 latency < 50ms at 500 RPS) and emit a clear PASS or FAIL verdict at the end of each run. The stress scenario MUST always exit with code 0 regardless of threshold breaches — threshold data is captured in the report for human review but does not gate CI.
- **FR-009**: The benchmark output MUST be machine-readable (JSON or CSV) in addition to a human-readable summary, to allow integration with CI reporting.

### Key Entities

- **Load Scenario**: A named, parameterized test profile describing virtual user count, ramp shape, duration, and target RPS.
- **Fake Record**: A generated data object conforming to a specific entity's schema (User, Video, or Comment), produced fresh for each request to avoid duplicate-key collisions.
- **Metric Threshold**: A configured pass/fail boundary for a specific metric (e.g., p95 latency, error rate) evaluated at the end of a run.
- **Run Report**: The benchmark's output artifact — machine-readable metrics plus a human-readable summary and verdict.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The benchmark suite can sustain 500 requests/second against the producer app for at least 60 seconds with a measured error rate below 1%.
- **SC-002**: p95 HTTP response latency remains below 50ms at the 500 RPS sustained load target.
- **SC-003**: All currently available endpoint operations are exercised within a single benchmark run: User CREATE, User UPDATE, User DELETE, and Video CREATE. Comments and Video UPDATE/DELETE are deferred until those producer endpoints ship (tracked in `todos.md`).
- **SC-004**: A benchmark run produces a structured report within 5 seconds of test completion that includes throughput, latency percentiles, and a PASS/FAIL verdict.
- **SC-005**: The benchmark configuration (target RPS, duration, thresholds) can be changed and a new run started in under 2 minutes without editing benchmark script source.

## Assumptions

- **A-001**: The producer app (006-producer-app) is fully deployed and accessible on the Docker network before benchmarking begins.
- **A-002**: The xk6 faker extension is available in the benchmark runtime environment (pre-built binary or Docker image).
- **A-003**: The benchmark tool runs on the same Docker network as the producer app; no external network routing is required.
- **A-004**: The PostgreSQL schema matches Feature 001 — Users, Videos, Comments tables with the expected foreign-key relationships.
- **A-005**: The benchmark does not require data cleanup between runs; the database is expected to accumulate records during testing.

## Clarifications

### Session 2026-02-20

- Q: SC-003 asserts all three entity types and all three CRUD ops must be exercised, but Comments and Video UPDATE/DELETE are not yet implemented in the producer. Should SC-003 be scoped to available endpoints only? → A: Yes — SC-003 scoped to User CRUD + Video CREATE; Comments and Video UPDATE/DELETE deferred until producer endpoints ship.
- Q: For CI integration, what exit code should the stress scenario emit when it deliberately breaches thresholds? → A: Always exit 0 for stress runs; threshold breaches are captured in the report for human review only, not as a CI gate.
- Q: If setup() pool seeding partially fails, should the benchmark abort or proceed with a partial pool? → A: Proceed if at least 10 users and 5 videos are seeded; abort below those minimums with a clear error.
- Q: Should the CRUD workload distribution weights (User CREATE/UPDATE/DELETE, Video CREATE) be user-configurable or fixed? → A: Fixed in code (40% User CREATE, 20% User UPDATE, 10% User DELETE, 30% Video CREATE); documented in README, not exposed as env vars.

## Non-Functional Requirements

- **NFR-001**: The benchmark runner MUST NOT itself become a bottleneck — it must be capable of generating at least 1000 RPS from a single host to support stress-test scenarios.
- **NFR-002**: The benchmark suite MUST be runnable with a single command (e.g., `docker run` or a shell script) requiring no manual setup steps beyond having the producer app running.
- **NFR-003**: No authentication or authorization is required for benchmark-to-producer communication, consistent with NFR-004 of the producer app.
