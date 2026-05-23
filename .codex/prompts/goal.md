---
description: Maintain persistent goal, verification, review, and resume state for long-running project work
---

## User Input

```text
$ARGUMENTS
```

Consider the user input before proceeding. If it changes the active goal, update `.codex/goal-state.md` before implementation work.

## Purpose

Use this command for work that may span multiple turns or agents. It keeps an explicit state ledger in `.codex/goal-state.md` so each turn resumes from repository facts and recorded verification, not memory alone.

## State File

State file: `.codex/goal-state.md`

If missing, create it with:

- Active Goal
- Current Repo Facts
- Scope
- Task Ledger
- Verification Ledger
- Review Ledger
- Decisions And Assumptions
- Blockers
- Next-Turn Resume Notes

If present, read it first and preserve useful history. Update it whenever facts, tasks, verification, review findings, decisions, blockers, or next steps change.

## Turn Protocol

Every `/goal` turn must:

1. Load context
   - Read `.codex/goal-state.md`.
   - Read `todos.md` if present.
   - Read relevant specs under `specs/`.
   - Run `git status --short`.
   - Inspect the implementation files that may be changed.

2. Reconcile facts
   - Compare state claims with the current repo.
   - Correct stale status before editing.
   - Do not trust checked-off task lists unless code and tests confirm them.
   - Record contradictions in `Current Repo Facts` or `Blockers`.

3. Execute a focused slice
   - Choose the next smallest coherent task from `Task Ledger`.
   - State what will change and what verification will prove it.
   - Preserve unrelated user changes.
   - Prefer existing repo patterns, scripts, contracts, and constitution rules.

4. Verify
   - Run narrow checks first.
   - For runtime, API, pipeline, or performance-affecting work, normally produce a minimal benchmark or smoke report for user review.
   - Prefer fast report settings before full-load runs, for example a low-rate sustained benchmark or targeted smoke script.
   - Record each command in `Verification Ledger` with command, result, date, report path if any, and evidence summary.
   - If a benchmark/report is blocked or not applicable, record why and name the strongest substitute verification.

5. Review quality
   - Use `/review` or an equivalent code-review pass at meaningful checkpoints:
     - after a complete endpoint/workflow slice,
     - before declaring the goal complete,
     - after any high-risk schema, concurrency, retry, or pipeline-contract change.
   - Do not run review after every tiny edit unless the change is risky.
   - Record review status, findings, and resolutions in `Review Ledger`.
   - Do not mark the goal complete while unresolved high- or medium-severity review findings remain.

6. Persist state before stopping
   - Update task checkboxes.
   - Update verification and review ledgers.
   - Update decisions, assumptions, blockers, and next-turn notes.
   - Include exact commands already run and exact commands still needed.

## Completion Criteria

Only report the active goal complete when all are true:

- Requested behavior is implemented.
- Implementation matches authoritative repo contracts.
- Required tests or smoke checks passed, or skipped checks have a concrete accepted reason.
- A minimal benchmark or runtime smoke report exists for user review when applicable, or the state file explains why it is blocked/not applicable and names the substitute evidence.
- A final `/review` or equivalent review pass found no unresolved high- or medium-severity issues.
- `.codex/goal-state.md` says the goal is complete and includes final verification/review evidence.
- `git status --short` was reviewed and the final response names changed files.

## Project Defaults

For `data-sync-opensearch`:

- Purpose: local CDC pipeline from PostgreSQL to OpenSearch using Debezium, Kafka, a Go consumer, a Go producer API, and xk6 benchmarks.
- Authoritative schema: `postgres/init/01-create-schema.sql`.
- Producer API should align with that schema, not stale UUID-only test tables.
- Known producer gap: Video update/delete and full Comments CRUD are missing.
- Benchmark expansion for video/comment operations is optional until producer support exists and consumer readiness is confirmed.
- For producer/API completion, expected external evidence is normally a low-rate benchmark or smoke report, such as `BENCHMARK_TARGET_RPS=20 BENCHMARK_DURATION=15s make -C benchmark run-sustained`, after the stack is ready.

## Final Response

Keep it concise. Include what changed, verification results, benchmark/smoke report path or skip reason, review status, state-file readiness, and remaining blockers.
