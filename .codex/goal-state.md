# Goal State

Last updated: 2026-05-24

## Active Goal

Update and verify the Docker Compose data sync pipeline so Producer CUD operations flow through Debezium CDC, Kafka, the Go consumer, and OpenSearch with at-least-once delivery, idempotent writes, optimistic locking, scalable consumers, benchmark scenarios, and a simple monitoring/control web entry point.

Priority order:

1. Canonical schema and producer API completion.
2. Consumer/OpenSearch contract alignment with idempotency and optimistic locking verified.
3. Docker Compose end-to-end validation for CUD -> eventual read consistency.
4. 500-600 RPS benchmark path with scalable consumer settings and an explicit partition/keyed-worker scale plan.
5. Monitoring/control web entry point for benchmark rate, consumer count, and Kafka metadata.

## Current Repo Facts

- Project purpose: Docker-first CDC pipeline from PostgreSQL to OpenSearch using Debezium, Kafka, a Go consumer, a Go producer API, and xk6 benchmarks.
- Top-level flow: PostgreSQL -> Debezium -> Kafka -> Consumer App -> OpenSearch.
- SpecKit workflow exists under `.codex/prompts/speckit.*.md` and `specs/`.
- Authoritative database schema is `postgres/init/01-create-schema.sql`.
- The authoritative schema is dataset-shaped:
  - `videos(video_id, title, category, created_at, updated_at)`
  - `users(channel_id, channel_name, created_at, updated_at)`
  - `comments(comment_id, video_id, channel_id, comment_text, likes, replies, published_at, sentiment_label, country_code, created_at, updated_at)`
- Producer has been updated in this turn to use the canonical dataset schema for users/channels, videos, and comments.
- Producer now exposes User, Video, and Comment create/update/delete routes.
- Producer contract and integration tests now initialize from the canonical Postgres schema.
- `todos.md` also identifies missing producer endpoints and benchmark placeholders for future endpoints.
- Benchmark suite now exercises create/update/delete workload across users, videos, and comments using canonical fields.
- Consumer transforms and unit fixtures were updated to canonical user/video/comment fields.
- OpenSearch mappings were updated to canonical fields and date formats accepting epoch millis or ISO strings.
- Consumer DLQ producer is now wired into message failure handling; poison messages are marked only after successful DLQ publication.
- Docker Compose now includes Kafbat UI on port `8084`, removes fixed host port publishing from scalable `consumer` replicas, and moves producer metrics from host `9092` to `9091`.
- Ops console service exists under `ops-console/`; it serves a browser UI on port `8090`, probes pipeline components, scales consumer replicas, and launches benchmark runs through Docker Compose.
- Consumer message handling now preserves Kafka partition order during CDC processing to prevent stale create events from overwriting later updates.
- Consumer group configuration explicitly uses marked-message offset commits for at-least-once processing and round-robin group rebalancing for scaled replicas.
- Consumer DLQ messages preserve original topic/partition/offset/key/value and include configured consumer-group metadata.
- Consumer delete handling now ignores stale delete events when the indexed document has a newer `source_ts_ms`.
- Ops console benchmark runs now use host-resolved bind mounts and write k6 raw/summary reports to `benchmark/reports/`.
- Ops console status now exposes the `cdc-consumer-group` Kafka lag table directly, alongside links to Kafbat UI and Kafka UI.
- A repeatable read-consistency verifier exists at `scripts/verify-read-consistency.sh` and is wired through `make verify-read-consistency`.
- Consumer scale is constrained by CDC ordering: normal consumer-group horizontal scale should come from Kafka topic partitions keyed by entity ID, with optional keyed worker lanes inside each consumer. Share-group or unkeyed per-partition concurrency requires stronger version/tombstone guarantees before it is acceptable for the primary CDC indexer.
- The local 500-600 RPS scale plan is documented at `docs/consumer-scale-plan.md`: 6 partitions per CDC/DLQ topic, 4 consumer replicas, and 0 post-run lag target.
- `make scale-cdc-topics` applies the local partition target to existing CDC and DLQ topics.
- A finish audit exists at `.codex/project-finish-audit.md`.
- Broader finish-readiness scan found additional gaps beyond producer:
  - Debezium tasks file has unchecked TODOs while also claiming 100% complete.
  - Kafka validation has unchecked performance/report/repeatability tasks.
  - Consumer has deferred end-to-end, failure, offset-resume, health, and final validation tasks.
  - Producer, consumer transforms, OpenSearch mappings, benchmark payloads, and producer specs do not all agree on the canonical Postgres schema.

## Scope

In scope:

- Add and maintain `.codex/prompts/goal.md`.
- Maintain this file as the turn-to-turn state ledger.
- Align every pipeline component to `postgres/init/01-create-schema.sql`.
- Keep producer, Debezium, Kafka topics/groups, consumer transforms, OpenSearch mappings, benchmarks, and docs mutually consistent.
- Implement Docker Compose validation scenarios for eventual consistency and 500-600 RPS load where machine capacity allows.
- Define and verify a consumer scale plan: Debezium CDC topics keyed by primary key, enough topic partitions for target replicas, consumer group lag visibility, and no stale writes under scaled processing.
- Add or integrate a monitoring/control web entry point.
- Record verification and review evidence after meaningful work slices.
- Produce a minimal benchmark or runtime smoke report for user review before marking runtime-affecting goals complete, unless blocked or not applicable.

Out of scope unless explicitly requested:

- Replacing the SpecKit workflow.
- Broad schema redesign away from `postgres/init/01-create-schema.sql`.

## Task Ledger

- [x] Scan repository purpose and current component state.
- [x] Decide that `/goal` should include both a reusable command prompt and a project-specific state file.
- [x] Decide that `.codex/goal-state.md` is the between-turn state file.
- [x] Decide that producer work must align to `postgres/init/01-create-schema.sql`.
- [x] Decide that completion criteria should normally include a minimal benchmark or runtime smoke report for user review.
- [x] Decide that `/review` or equivalent review passes should be used at meaningful quality gates.
- [x] Create `.codex/prompts/goal.md`.
- [x] Initialize `.codex/goal-state.md`.
- [x] Scan codebase for project finish-readiness gaps.
- [x] Create `.codex/project-finish-audit.md`.
- [x] Use `/goal` protocol for producer completion.
- [x] Reconcile producer models and tests with the authoritative Postgres schema.
- [x] Implement missing producer Video update/delete endpoints.
- [x] Implement missing producer Comments create/update/delete endpoints.
- [x] Update producer contracts/docs to match implemented schema and endpoints.
- [x] Run producer tests and record results.
- [x] Update benchmark payload builders to canonical schema.
- [x] Survey monitoring web console options with sub-agent.
- [x] Align consumer transforms/tests and OpenSearch mappings to canonical schema.
- [x] Wire consumer DLQ publication into processing failure path.
- [x] Add scalable consumer Compose settings and resolve host port conflicts for scaling.
- [x] Add Kafbat UI compose integration for Kafka metadata and Connect visibility.
- [x] Expand benchmark workload to include producer CUD scenarios for videos/comments.
- [x] Add control API or ops page for benchmark input rate and consumer replica count.
- [x] Run Docker smoke checks when available and record results.
- [x] Produce a minimal benchmark or runtime smoke report, or record the concrete blocker/substitute verification.
- [x] Add repeatable producer CUD plus concurrent OpenSearch read consistency verification.
- [x] Run a 500 RPS benchmark attempt with scaled consumers and record whether this machine sustained it.
- [x] Document and verify the partition/keyed-worker consumer scale plan beyond the current two-replica benchmark.
- [x] Run final `/review` or equivalent review and resolve high/medium findings.
- [ ] Run final `/review` or equivalent review and resolve high/medium findings.

## Verification Ledger

| Date | Command | Result | Report | Evidence |
|---|---|---|---|---|
| 2026-05-23 | `rg --files`, `git status --short`, `git log --oneline -8`, README/spec/code inspection | PASS | n/a | Repo purpose, component layout, missing producer endpoints, and schema mismatch identified. |
| 2026-05-24 | `test -f .codex/prompts/goal.md ...`, `test -f .codex/goal-state.md ...`, `git status --short` | PASS | n/a | Confirmed no prior goal files were present after aborted patch attempts. |
| 2026-05-24 | `python3` task-count scan over `specs/*/tasks.md` | PASS | `.codex/project-finish-audit.md` | Identified unchecked task counts: Debezium 5, Kafka 9, Consumer 12; Producer and Benchmark checked but contract drift remains. |
| 2026-05-24 | `go test ./...` in `consumer` | PASS | n/a | Consumer unit tests pass, but audit notes tests are too weak to prove canonical schema alignment. |
| 2026-05-24 | `GOCACHE=/tmp/data-sync-go-cache go test ./cmd/... ./internal/... ./pkg/...` in `producer` | PASS | n/a | Producer packages compile; no package tests outside integration/contract packages. |
| 2026-05-24 | `GOCACHE=/tmp/data-sync-go-cache go test ./...` in `producer` | BLOCKED | n/a | Testcontainers suites blocked by missing Docker runtime: `rootless Docker not found`. |
| 2026-05-24 | `go test ./...` in `producer` | PASS | n/a | Producer contract and integration suites pass against canonical schema after CUD endpoint completion. |
| 2026-05-24 | `docker compose config` | PASS | `/tmp/data-sync-compose-config.txt` | Compose config renders successfully after producer/API changes. |
| 2026-05-24 | `go test ./...` in `consumer` | PASS | n/a | Existing consumer unit tests still pass; canonical schema alignment remains incomplete. |
| 2026-05-24 | `make build-producer` | BLOCKED | n/a | Producer binary built, but Docker image build failed because Docker daemon at Colima socket is unavailable. |
| 2026-05-24 | `jq empty opensearch/mappings/*.json` | PASS | n/a | Canonical OpenSearch mapping JSON files are valid. |
| 2026-05-24 | `go test ./...` in `consumer` | PASS | n/a | Consumer canonical transform and DLQ wiring changes compile and existing unit tests pass. |
| 2026-05-24 | `go test ./...` in `producer` | PASS | n/a | Producer canonical schema/API changes continue to pass integration and contract tests. |
| 2026-05-24 | `docker compose config` | PASS | `/tmp/data-sync-compose-config.txt` | Compose config renders with scalable consumer settings, Kafbat UI, and producer metrics port fix. |
| 2026-05-24 | `node --check benchmark/scripts/...` | PASS | n/a | Benchmark libraries and scenario files parse after CUD workload expansion. |
| 2026-05-24 | `go test ./...` in `ops-console` | PASS | n/a | Ops console control API and embedded UI compile. |
| 2026-05-24 | `docker info` | BLOCKED | `/tmp/data-sync-docker-info.txt` | Docker client is installed, but daemon is unavailable at Colima socket, so runtime Compose smoke/benchmark cannot run yet. |
| 2026-05-24 | `colima start --cpu 4 --memory 8 --disk 60`; `docker info` | PASS | n/a | Docker daemon became reachable: Docker 27.4.0 on Ubuntu 24.04.1 LTS. |
| 2026-05-24 | `make start-ops-console`; `curl http://localhost:8090/api/status` | PASS | n/a | Ops console built and served status; probes became healthy after app stack start. |
| 2026-05-24 | `docker compose --profile app up -d`; `make register-connector`; `make create-indices` | PASS | n/a | Compose app stack started, Debezium connector registered, OpenSearch indices created or already existed. |
| 2026-05-24 | Producer CUD smoke with `smoke3-*` IDs, then OpenSearch document reads | PASS | n/a | Users/videos/comments were indexed after CDC envelope and missing-date fixes; `smoke4-*` later showed a user stale-overwrite risk before `source_ts_ms` freshness fix. |
| 2026-05-24 | `make -C benchmark build` | PASS | n/a | Benchmark image built after changing xk6 output path from `/k6` to `/tmp/k6`. |
| 2026-05-24 | Ops console benchmark launch at 500 RPS for 15s | BLOCKED | n/a | Original console launcher used `docker compose run` inside `/workspace`, created a second `workspace` project, collided on port 9092, and disrupted app services. Safer `docker run --network data-sync-opensearch_default` path was implemented but still needs rerun. |
| 2026-05-24 | `go test ./...` in `consumer`; `go test ./...` in `ops-console` | PASS | n/a | Consumer and ops-console compile after `source_ts_ms` freshness and safe benchmark launcher changes. |
| 2026-05-24 | Ordered producer CUD smoke with `ordered-*` IDs, then OpenSearch document reads | PASS | n/a | User, video, and comment updates indexed with expected updated fields and `source_ts_ms` after consumer processing was changed to preserve per-partition order. |
| 2026-05-24 | `node --check benchmark/scripts/main.js ... scenarios/*.js`; `docker compose config` | PASS | n/a | Benchmark script syntax and Compose config render after faker API, `/reports` summary paths, k6 expected-status, and host bind mount fixes. |
| 2026-05-24 | Ops console low-rate benchmark: sustained, 50 target RPS, 10s duration, pools 20/10/10 | PASS | `benchmark/reports/sustained-summary.json` | k6 exit code 0; 1,299 iterations, 1,340 HTTP requests, `http_req_failed` rate 0, checks rate 1.0, global p95 1.23 ms, thresholds passed. |
| 2026-05-24 | `curl -X POST http://localhost:8090/api/scale -d '{"replicas":2}'`; `docker compose ps consumer` | PASS | n/a | Ops console scaled `consumer` to 2 replicas without recreating a separate Compose project or disrupting probes. |
| 2026-05-24 | `curl http://localhost:8090/api/status` | PASS | n/a | Producer, consumer, and OpenSearch probes returned HTTP 200; last benchmark reported exit code 0. |
| 2026-05-24 | `go test ./...` in `consumer`; `go test ./...` in `ops-console`; benchmark `node --check`; `docker compose config`; `git diff --check` | PASS | n/a | Checkpoint verification passed before committing ordered CDC and benchmark-report fixes. |
| 2026-05-24 | `make verify-read-consistency` | PASS | n/a | Run `verify-1779578401-2625` drove producer CUD operations, performed 72 concurrent OpenSearch reads, then verified final updated user/video/comment documents and deleted user/video/comment documents. |
| 2026-05-24 | Ops console benchmark: sustained, 500 target RPS, 15s duration, 2 consumer replicas, pools 100/50/50 | PASS | `benchmark/reports/sustained-summary.json` | k6 exit code 0; 10,775 iterations, 10,976 HTTP requests, `http_req_failed` rate 0, checks rate 1.0, p95 0.95 ms. Raw stream showed one-second buckets at 500-501 iterations/s during target stage. |
| 2026-05-24 | `docker compose exec -T kafka kafka-consumer-groups --bootstrap-server kafka:9092 --describe --group cdc-consumer-group` | PASS | n/a | Lag was 0 for `dbserver.public.users`, `dbserver.public.videos`, and `dbserver.public.comments` after the 500 RPS benchmark; two consumers were active in the group. |
| 2026-05-24 | `docker compose ps --format json`; `curl http://localhost:8090/api/status` during/after 500 RPS benchmark | PASS | n/a | Compose services remained running; producer, consumer, and OpenSearch probes returned HTTP 200. |
| 2026-05-24 | `go test ./...` in `ops-console`; `bash -n scripts/verify-read-consistency.sh`; `docker compose --profile ops up -d --build ops-console`; `/api/status` Kafka metadata check | PASS | n/a | Ops console rebuilt with configurable Kafka consumer-group metadata in status response; `kafka_group` was `cdc-consumer-group`, `kafka_group_error` was empty, and the lag table had 4 non-empty lines. |
| 2026-05-24 | `go test ./...` in `consumer`; `docker compose config`; `git diff --check` | PASS | n/a | Checkpoint verification passed for consumer tests, Compose render, and whitespace/errors after read-consistency and console metadata changes. |
| 2026-05-24 | `go test ./...` in `consumer` | PASS | n/a | Added focused unit coverage for consumer-group delivery settings, DLQ message metadata, poison-message marking only after DLQ publish success, and `source_ts_ms`/`updated_at` stale-update rejection. |
| 2026-05-24 | `CDC_TOPIC_PARTITIONS=6 make scale-cdc-topics` | PASS | n/a | Existing CDC and DLQ topics were increased to 6 partitions each; `KAFKA_NUM_PARTITIONS=6` was added for future auto-created topics. |
| 2026-05-24 | Ops console scale API to 4 consumers, then `docker compose ps consumer` | PASS | n/a | Four consumer replicas were running; a later 4->3->4 scale changed only consumer containers after the Kafka partition config had been applied. |
| 2026-05-24 | `make verify-read-consistency` after topic partition scaling | PASS | n/a | Run `verify-1779578994-19292` passed with 120 concurrent OpenSearch reads and final CUD consistency under 4 consumers and 6 topic partitions. |
| 2026-05-24 | Ops console benchmark: sustained, 500 target RPS, 15s duration, 4 consumer replicas, 6 CDC partitions per topic | PASS | `benchmark/reports/sustained-summary.json` | k6 exit code 0; 10,775 iterations, 10,976 HTTP requests, `http_req_failed` rate 0, checks rate 1.0, p95 1.09 ms. Raw stream showed one-second buckets at 500-501 iterations/s during target stage. |
| 2026-05-24 | Kafka consumer group lag after scaled 500 RPS benchmark | PASS | n/a | Lag was 0 across all 18 CDC partitions for `dbserver.public.users`, `dbserver.public.videos`, and `dbserver.public.comments`; four consumers were assigned partitions. |
| 2026-05-24 | Status probes during scaled benchmark | PASS | n/a | Producer, consumer, and OpenSearch probes returned HTTP 200; Compose services remained running. |
| 2026-05-24 | `go test ./...` in `producer`, `consumer`, and `ops-console`; benchmark `node --check`; verifier `bash -n`; `docker compose config`; `git diff --check` | PASS | n/a | Final verification pass before review completed successfully. |
| 2026-05-24 | Stale-delete guard review and `go test ./...` in `consumer` | PASS | n/a | Review found unconditional OpenSearch deletes could remove newer documents under replay; delete now checks `source_ts_ms`, and stale-delete unit tests pass. |
| 2026-05-24 | Rebuilt `consumer` image with 4 replicas; `make verify-read-consistency` | PASS | n/a | Run `verify-1779579291-1817` passed with 180 concurrent OpenSearch reads using the stale-delete runtime. |
| 2026-05-24 | Final ops-console benchmark after stale-delete guard: sustained, 500 target RPS, 15s duration, 4 consumer replicas, 6 CDC partitions per topic | PASS | `benchmark/reports/sustained-summary.json` | k6 exit code 0; 10,774 iterations, 10,975 HTTP requests, `http_req_failed` rate 0, checks rate 1.0, p95 1.10 ms; raw stream showed repeated 500 iterations/s buckets. |
| 2026-05-24 | Final Kafka lag after stale-delete benchmark | PASS | n/a | Lag was 0 across all 18 CDC partitions after the final 500 RPS run. |

## Review Ledger

| Date | Review | Result | Findings |
|---|---|---|---|
| 2026-05-24 | Planning review with user feedback | PASS | Added minimal benchmark/report expectation and `/review` quality gates to the protocol. |
| 2026-05-24 | Monitoring console survey by sub-agent | PASS | Recommended Grafana + Prometheus + Kafbat UI plus thin control API; lighter interim option is Kafbat UI + OpenSearch Dashboards + small ops page/API. |
| 2026-05-24 | Focused review of read-consistency script and ops-console Kafka status | PASS | Found hardcoded consumer group in status API; fixed with `OPS_CONSOLE_CONSUMER_GROUP` defaulting to `cdc-consumer-group`. |
| 2026-05-24 | Final requirement review | PASS | Found stale-delete risk; fixed with `source_ts_ms` delete guard. No remaining high/medium findings after final tests, read-consistency smoke, 500 RPS benchmark, zero-lag check, and status probes. |

## Decisions And Assumptions

- `.codex/goal-state.md` is the durable state ledger for Codex agents working in this repo.
- `/goal` should be reusable for future work, but this state file starts with the producer-completion objective.
- `postgres/init/01-create-schema.sql` is authoritative for producer API contract alignment.
- Monitoring recommendation: use Grafana + Prometheus + Kafbat UI plus a thin control API for benchmark rate and consumer scale controls; Kafbat-only plus ops page is acceptable for a lighter first version.
- Benchmark expansion can begin after consumer/OpenSearch field alignment is complete.
- Integration tests are required for producer API changes because this repo's constitution treats integration testing as mandatory.
- For runtime-affecting goals, completion should normally include a minimal external-judgement artifact, such as a benchmark JSON report or smoke report.
- `/review` should be used as a milestone quality gate, especially before goal completion, but not after every trivial edit.
- Scaling decision: for the primary CDC indexer, prefer normal Kafka consumer groups over Kafka share groups. Scale horizontally by increasing CDC topic partitions and consumer replicas, preserving per-entity order by key; add keyed worker lanes only if they preserve per-key ordering. Share groups are deferred unless WAL/LSN-based external versioning and delete tombstones are implemented and verified.

## Blockers

- Finish readiness depends on resolving cross-component schema drift, not only adding missing producer endpoints.
- Docker/Colima is now reachable and the Compose stack has been exercised.
- Runtime smoke exposed and resolved CDC/consumer issues:
  - Debezium emits schemaless CDC envelopes while the consumer originally expected nested `payload`.
  - OpenSearch rejected empty `published_at` values for comments until the consumer began omitting missing dates.
  - User create/update events can arrive out of processing order, so consumer documents now include `source_ts_ms` for freshness checks.
- Worker-pool parallelism broke Kafka per-partition ordering; the backpressure handler now processes claim messages sequentially to preserve ordering before offset marking.
- Ops console and benchmark image build now work. The safer benchmark path has produced a passing low-rate k6 report.
- 500 target RPS validation has produced a passing k6 report with 0 Kafka lag after completion; this machine sustained 500-501 iteration/s buckets during the target stage.
- Explicit read-consistency scenario coverage now exists through `make verify-read-consistency`.
- At-least-once/DLQ and optimistic-lock behavior have focused unit coverage and runtime smoke coverage.
- Review gap fixed: deletes are now source-timestamp guarded so stale replayed deletes do not remove newer indexed documents.
- Explicit scale plan is now implemented and verified for the local 500 RPS run.
- Final review is complete with no remaining high/medium findings.

## Next-Turn Resume Notes

Start by invoking or following `.codex/prompts/goal.md`.

Recommended next work slice:

The goal is complete at commit `a636ce1` plus this final state update. The Compose stack is running with 4 consumers, 6 CDC partitions per topic, healthy probes, and 0 Kafka lag after the final 500 RPS benchmark.
