# Requirements Quality Checklist: xk6 Benchmark Suite

**Purpose**: Author self-review of requirements quality across all four specification clusters before beginning Phase 1 implementation. Each item tests whether the *requirements themselves* are complete, clear, consistent, and measurable — not whether the implementation works.
**Created**: 2026-02-21
**Feature**: [spec.md](../spec.md) | [plan.md](../plan.md) | [tasks.md](../tasks.md)
**Scope**: Load profile specs · Data generation & referential integrity · CI output & reports · NFRs & assumptions
**Run after**: `/speckit.analyze` ✅ | **Run before**: `/speckit.implement`

---

## Load Profile Specification Quality

*Are the three scenario load profiles defined completely, consistently, and measurably across all artifacts?*

- [ ] CHK001 — Is the sustained load scenario's three-phase shape (warm-up → sustained hold → cool-down) consistently documented across spec.md, plan.md, and contracts/benchmark-scenarios.md, or does each artifact describe a different profile? [Consistency, Spec §FR-001 — **H1 from analysis: plan.md describes flat 500 RPS/120s; contract specifies 10s/50 RPS warm-up + 10s cool-down**]

- [ ] CHK002 — Are the specific numeric stage parameters for the ramp-up scenario (30s→50 RPS, 30s→200 RPS, 30s→500 RPS, 60s hold, 15s ramp-down) consistently documented across spec.md §US-2, plan.md Phase 3, and contracts/benchmark-scenarios.md — with no drift in values between documents? [Consistency, Spec §US-2]

- [ ] CHK003 — Is the stress scenario's load ceiling specified with a measurable definition of "saturation point" rather than a range ("1000–2000 RPS")? Is the definition of saturation (e.g., error rate first exceeds X%) explicitly documented as the authoritative stopping criterion? [Clarity, Spec §US-3, §NFR-001]

- [ ] CHK004 — Are the PASS/FAIL threshold values (p95 < 50ms, error rate < 1%) explicitly scoped to the sustained and ramp-up scenarios only, with a clear statement that the same thresholds are intentionally present-but-not-gating for the stress scenario? [Clarity, Spec §FR-008]

- [ ] CHK005 — Is the CRUD workload mix (40% User CREATE, 20% User UPDATE, 10% User DELETE, 30% Video CREATE) documented as summing to exactly 100%, and is there a recorded rationale for each weight so future changes can be evaluated for statistical validity? [Completeness, Spec §FR-003]

- [ ] CHK006 — Are the `BENCHMARK_DURATION` default (120s) and `BENCHMARK_TARGET_RPS` default (500) consistent across all locations where they appear: spec.md §FR-006, data-model.md §4 configuration table, plan.md Phase 1, and the env var block in the Makefile/Docker Compose entries? [Consistency, Spec §FR-006]

- [ ] CHK007 — Is the "always exit 0" rule for the stress scenario explicitly scoped: does it apply only to threshold breaches, or also to unexpected runtime errors such as connection refused, script parse failure, or pool seeding abort? [Clarity, Spec §FR-008]

---

## Data Generation & Referential Integrity Requirements

*Are fake-data schemas, uniqueness strategies, pool rules, and referential integrity constraints fully and unambiguously specified?*

- [ ] CHK008 — Are the data type and format constraints for all User entity fields (`username`, `email`) fully specified — including max length, character set, or uniqueness guarantee — beyond the general description in data-model.md, so that a database constraint violation during seeding would be predictable? [Completeness, data-model.md §1, Spec §A-004]

- [ ] CHK009 — Is the uniqueness strategy for `username` (timestamp suffix) and `email` (UUID prefix) documented as normative in the spec or data model, with explicit acknowledgement of its failure modes under parallel VU generation — for example, two VUs generating a username in the same millisecond? [Clarity, data-model.md §1]

- [ ] CHK010 — Is the Video entity's `duration` range (60–7200 seconds) specified with a rationale that aligns to the producer app's database constraints, or is it a benchmark-only choice that may silently violate a schema rule? Does Spec §A-004 cover this? [Assumption, data-model.md §1, Spec §A-004]

- [ ] CHK011 — Is the minimum pool seeding requirement (≥10 users, ≥5 videos before the benchmark proceeds) documented in a normative requirement (FR or SC section) rather than only in the edge cases list, where it may be overlooked during requirements review? [Completeness, Spec §edge cases, Gap]

- [ ] CHK012 — Is the Comment entity "placeholder" scope explicitly bounded in the requirements: specifically, does the spec define which artifacts exist (faker builder, data schema) vs. which are intentionally absent (no HTTP call, no scenario script), so the placeholder cannot be mistaken for partial implementation? [Clarity, Spec §FR-002]

- [ ] CHK013 — Is the referential integrity constraint chain (Video requires valid `user_id`, Comment requires valid `video_id` + `user_id`) consistently and completely documented across spec.md §FR-004, data-model.md §2, and contracts/benchmark-scenarios.md — with no artifact treating the constraint as implicit? [Consistency, Spec §FR-004, data-model.md §2]

- [ ] CHK014 — Are 404-on-DELETE and 409-on-CREATE outcomes each specified with a concrete handling rule: are these responses counted in the raw NDJSON output, excluded from the error rate calculation, and visible in the PASS/FAIL verdict logic? Or does the spec leave their metric treatment undefined? [Completeness, Spec §FR-005, §edge cases, Gap]

---

## CI Output & Machine-Readable Report Requirements

*Are report filenames, schemas, exit codes, and CI integration patterns specified to the level a pipeline engineer could act on them without reading k6 documentation?*

- [ ] CHK015 — Are all report filenames (`sustained-summary.json`, `sustained-raw.ndjson`, `ramp-summary.json`, `ramp-raw.ndjson`, `stress-summary.json`, `stress-raw.ndjson`) listed consistently in spec.md, plan.md, contracts/, and quickstart.md with no naming drift between artifacts? [Consistency, Spec §FR-009, quickstart.md]

- [ ] CHK016 — Is the JSON summary report schema defined or referenced — are the top-level fields and their types documented anywhere, or is the format implicitly delegated to "whatever the k6 `handleSummary` data object emits"? Would a downstream dashboard or CI script know what keys to expect? [Completeness, Spec §FR-009, data-model.md §3, Gap]

- [ ] CHK017 — Is the NDJSON raw output format specified beyond the three fields documented in data-model.md §3 (`metric`, `data.value`, `data.tags`)? Are timestamp field, unit, or schema version documented so time-series consumers can parse samples without guessing? [Completeness, data-model.md §3, Gap]

- [ ] CHK018 — Is `breaking_point_rps` defined as a field in the stress report schema anywhere in the spec artifacts? The spec describes capturing the inflection point (§US-3) but does not specify the field name, data type, unit (RPS vs. VU count), or location in the JSON structure. [Gap, Spec §US-3, data-model.md §3]

- [ ] CHK019 — Is SC-004 ("structured report within 5 seconds of test completion") measurable as written? Is "test completion" defined as k6 process exit, `handleSummary` return, or file-write complete — and is 5 seconds measured from which event? [Clarity, Spec §SC-004]

- [ ] CHK020 — Are exit code semantics consistently documented across spec.md §FR-008, contracts/benchmark-scenarios.md, and quickstart.md — specifically: do all three agree on when exit code 0 vs. non-zero is produced, covering both threshold failures and unexpected runtime errors (e.g., producer unreachable)? [Consistency, Spec §FR-008, quickstart.md]

- [ ] CHK021 — Is the CI integration pattern (artifact upload path, `--exit-code-from` flag usage, environment variable injection) specified to a level of detail that a CI engineer could configure it without reading k6 or Docker Compose documentation? Does spec.md §FR-009 or quickstart.md provide this, or is it left as an exercise? [Completeness, Spec §FR-009, quickstart.md, Gap]

---

## Non-Functional Requirements & Assumptions Quality

*Are NFRs measurable and verifiable? Are assumptions explicitly bounded, risk-assessed, and traceable to requirements?*

- [ ] CHK022 — Is NFR-001 ("capable of generating ≥1000 RPS from a single host") verifiable as written? Is there a defined measurement method or acceptance test for the benchmark runner's own throughput ceiling, independent of the producer app's saturation point? [Measurability, Spec §NFR-001, Gap]

- [ ] CHK023 — Is NFR-002 ("runnable with a single command, no manual setup steps beyond having the producer app running") consistent with quickstart.md §1 ("Build the xk6 binary — first time only"), which requires a separate `make -C benchmark build` command? Does NFR-002 explicitly exclude the one-time build from its "no manual steps" guarantee? [Consistency, Spec §NFR-002, quickstart.md §1]

- [ ] CHK024 — Is A-001 ("producer app fully deployed and accessible") specified with a testable pre-condition — does the spec define what "accessible" means (protocol, port, expected health response) so the pre-flight health check in FR-007 can be validated against a concrete criterion? [Clarity, Spec §A-001, §FR-007]

- [ ] CHK025 — Is A-004 ("PostgreSQL schema matches Feature 001") documented as a validated assumption with a reference to the actual schema definition (e.g., a migration file or model spec), or is it an unverified dependency that could cause silent seeding failures without a clear error message? [Assumption, Spec §A-004]

- [ ] CHK026 — Are deferred endpoints (Video UPDATE, Video DELETE, all Comments CRUD) explicitly listed as out-of-scope with a cross-reference to `todos.md`, so an implementer reviewing only the spec cannot accidentally treat them as in-scope work items? [Completeness, Spec §SC-003, §FR-002, §FR-003]

- [ ] CHK027 — Is the Observability exemption for the benchmark runner (no `/health` or `/metrics` endpoint) documented in spec.md with a rationale, or only present in plan.md's Constitution Check table — meaning a spec-only reviewer would have no visibility into this deviation from Constitution Principle III? [Completeness, plan.md §Constitution Check, Gap]

- [ ] CHK028 — Are the pool size defaults (200 users, 100 videos) specified with a documented rationale explaining why these values are sufficient to avoid pool exhaustion during a 120s run at 500 RPS with a 10% DELETE rate — or are they arbitrary defaults with no traceability to the load model? [Completeness, Spec §FR-006, data-model.md §2, Gap]

---

## Notes

- Mark items `[x]` when requirement quality is confirmed as adequate, or annotate with a finding if remediation is needed
- Items marked `[Gap]` indicate a requirement is likely missing — add to spec.md before proceeding
- Items marked `[Consistency]` may require cross-artifact edits to align — check all referenced locations
- H1 from `/speckit.analyze` directly maps to CHK001 — confirm resolution before marking complete
- This checklist tests the *requirements*, not the implementation — if an item is "passing" only because you know the intent, the requirement needs to be made explicit
