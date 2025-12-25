# Tasks: OpenSearch Configuration with Demo Indices

**Input**: `/specs/004-opensearch-setup/spec.md`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Integration tests are included per constitution Principle III (NON-NEGOTIABLE)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

This is an infrastructure configuration project using:
- Docker Compose services at repository root
- OpenSearch configuration in `opensearch/` directory
- Integration tests in `opensearch/tests/`
- Documentation in `specs/004-opensearch-setup/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and Docker Compose foundation

- [ ] T001 Create OpenSearch directory structure (opensearch/config/, opensearch/mappings/, opensearch/scripts/, opensearch/demo-data/, opensearch/queries/)
- [ ] T002 Create integration test directory (opensearch/tests/)
- [ ] T003 [P] Add OpenSearch environment variables to .env.example

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Docker services and base configuration that MUST be complete before ANY user story

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T004 Add OpenSearch service to docker-compose.yml (image: opensearchproject/opensearch:2.11.0, ports: 9200, volumes, environment)
- [ ] T005 [P] Add OpenSearch Dashboards service to docker-compose.yml (image: opensearchproject/opensearch-dashboards:2.11.0, ports: 5601, depends_on opensearch)
- [ ] T006 [P] Create opensearch.yml cluster configuration in opensearch/config/opensearch.yml (single-node mode, cluster name, discovery type)
- [ ] T007 [P] Create log4j2.properties logging configuration in opensearch/config/log4j2.properties
- [ ] T008 Add Makefile target start-opensearch (docker-compose up opensearch opensearch-dashboards, wait-for-health)
- [ ] T009 [P] Add Makefile target stop-opensearch (docker-compose stop opensearch opensearch-dashboards)
- [ ] T010 [P] Add Makefile target restart-opensearch (calls stop-opensearch then start-opensearch)
- [ ] T011 [P] Add Makefile target status-opensearch (curl cluster health endpoint with jq formatting)
- [ ] T012 Create wait-for-health.sh script in opensearch/scripts/wait-for-health.sh (poll /_cluster/health until green)

**Checkpoint**: Foundation ready - OpenSearch cluster can start, user story implementation can now begin

---

## Phase 3: User Story 1 - Deploy OpenSearch with Pre-configured Indices (Priority: P1) 🎯 MVP

**Goal**: Deploy OpenSearch cluster with 3 pre-configured indices (videos_index, users_index, comments_index) matching PostgreSQL CDC schema

**Independent Test**: Start OpenSearch, run create-indices script, verify all 3 indices exist with correct mappings via GET /_cat/indices and GET /videos_index/_mapping

### Integration Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T013 [P] [US1] Create test-index-creation.sh in opensearch/tests/test-index-creation.sh (verify 3 indices exist, check mappings for each)
- [ ] T014 [P] [US1] Create test-document-insertion.sh in opensearch/tests/test-document-insertion.sh (insert test docs, verify indexed, search)
- [ ] T015 [P] [US1] Create test-cluster-health.sh in opensearch/tests/test-cluster-health.sh (verify green status, node count)

### Implementation for User Story 1

- [ ] T016 [P] [US1] Create videos-index.json mapping in opensearch/mappings/videos-index.json (copy from contracts/videos-index-mapping.json)
- [ ] T017 [P] [US1] Create users-index.json mapping in opensearch/mappings/users-index.json (copy from contracts/users-index-mapping.json)
- [ ] T018 [P] [US1] Create comments-index.json mapping in opensearch/mappings/comments-index.json (copy from contracts/comments-index-mapping.json)
- [ ] T019 [US1] Create create-indices.sh script in opensearch/scripts/create-indices.sh (PUT requests for all 3 indices with mappings, error handling)
- [ ] T020 [US1] Add Makefile target create-indices (calls opensearch/scripts/create-indices.sh)
- [ ] T021 [US1] Test index creation: run make create-indices, verify indices exist with correct mappings
- [ ] T022 [US1] Run integration tests for US1: ./opensearch/tests/test-index-creation.sh, test-document-insertion.sh, test-cluster-health.sh

**Checkpoint**: At this point, OpenSearch cluster deploys successfully with 3 pre-configured indices ready for CDC data

---

## Phase 4: User Story 2 - Execute Demo Queries with Multiple Ranking Strategies (Priority: P2)

**Goal**: Provide pre-built demo queries demonstrating 4+ ranking strategies (text relevance, recency, popularity, hybrid) with sample data loaded

**Independent Test**: Load demo data, execute each demo query script, verify results match expected ranking behavior (relevance scores decreasing, newest first, highest views first, hybrid combination)

### Integration Tests for User Story 2

- [ ] T023 [P] [US2] Create test-query-execution.sh in opensearch/tests/test-query-execution.sh (run all 4 demo queries, verify result counts >0, check score/sort ordering)

### Implementation for User Story 2

**Demo Data Generation**:

- [ ] T024 [P] [US2] Create generate-videos-data.sh script in opensearch/demo-data/generate-videos-data.sh (generate 1000 video documents in JSONL format)
- [ ] T025 [P] [US2] Create generate-users-data.sh script in opensearch/demo-data/generate-users-data.sh (generate 500 user documents in JSONL format)
- [ ] T026 [P] [US2] Create generate-comments-data.sh script in opensearch/demo-data/generate-comments-data.sh (generate 8500 comment documents in JSONL format)
- [ ] T027 [US2] Create load-demo-data.sh script in opensearch/scripts/load-demo-data.sh (call generate scripts, bulk index via /_bulk API, report stats)
- [ ] T028 [US2] Add Makefile target load-demo-data (calls opensearch/scripts/load-demo-data.sh)

**Demo Query Scripts**:

- [ ] T029 [P] [US2] Create relevance-search.sh in opensearch/queries/relevance-search.sh (multi_match query on title/description/tags, accepts search term param)
- [ ] T030 [P] [US2] Create recency-sort.sh in opensearch/queries/recency-sort.sh (match_all with sort by published_at desc)
- [ ] T031 [P] [US2] Create popularity-sort.sh in opensearch/queries/popularity-sort.sh (match_all with sort by view_count desc, tie-break by published_at)
- [ ] T032 [P] [US2] Create hybrid-ranking.sh in opensearch/queries/hybrid-ranking.sh (function_score with gauss decay on date, field_value_factor on views, accepts search term)
- [ ] T033 [P] [US2] Create filtered-aggregations.sh in opensearch/queries/filtered-aggregations.sh (bool query with category filter, aggregations on category/sentiment)
- [ ] T034 [US2] Create run-demo-queries.sh in opensearch/scripts/run-demo-queries.sh (execute all 5 query scripts, format output, show top results)
- [ ] T035 [US2] Add Makefile target run-demo-queries (calls opensearch/scripts/run-demo-queries.sh)
- [ ] T035a [US2] Document index mapping rationale in specs/004-opensearch-setup/research.md (field types, analyzers, updated_at usage)
- [ ] T035b [US2] Add query examples in multiple formats (REST curl, Query DSL JSON, optional client snippet) to specs/004-opensearch-setup/quickstart.md

**Testing**:

- [ ] T036 [US2] Test demo data loading: run make load-demo-data, verify 10K documents indexed across 3 indices
- [ ] T037 [US2] Test demo queries individually: run each query script in opensearch/queries/, verify results
- [ ] T038 [US2] Run integration test for US2: ./opensearch/tests/test-query-execution.sh

**Checkpoint**: At this point, demo queries execute successfully showing 4+ ranking strategies with realistic data

---

## Phase 5: User Story 3 - Monitor Index Health and Performance (Priority: P3)

**Goal**: Monitor OpenSearch cluster health, index statistics, and query performance via Dashboards and status commands

**Independent Test**: Access OpenSearch Dashboards at localhost:5601, verify cluster status visible, run status-opensearch command, check metrics displayed

### Integration Tests for User Story 3

- [ ] T039 [US3] Update test-cluster-health.sh to verify metrics endpoints (cluster stats, index stats, node info)

### Implementation for User Story 3

**Monitoring Configuration**:

- [ ] T040 [US3] Verify OpenSearch Dashboards service configured in docker-compose.yml (already in T005 foundational phase)
- [ ] T041 [US3] Update status-opensearch Makefile target to show detailed cluster stats (nodes, shards, indices count, disk usage)
- [ ] T042 [P] [US3] Create check-index-stats.sh script in opensearch/scripts/check-index-stats.sh (GET /_cat/indices?v, per-index doc counts and sizes)
- [ ] T043 [P] [US3] Create check-query-performance.sh script in opensearch/scripts/check-query-performance.sh (run sample query with profile=true, show timing breakdown)
- [ ] T044 [US3] Add Makefile target check-index-stats (calls opensearch/scripts/check-index-stats.sh)
- [ ] T045 [P] [US3] Add Makefile target check-query-performance (calls opensearch/scripts/check-query-performance.sh)

**Documentation Updates**:

- [ ] T046 [US3] Update quickstart.md Step 5 (Explore with OpenSearch Dashboards) with screenshots/detailed navigation
- [ ] T047 [P] [US3] Add monitoring section to quickstart.md documenting all status commands and expected outputs

**Testing**:

- [ ] T048 [US3] Test monitoring: Start Dashboards, access localhost:5601, verify cluster overview loads
- [ ] T049 [US3] Test status commands: run make status-opensearch, check-index-stats, check-query-performance, verify output
- [ ] T050 [US3] Run integration test for US3: ./opensearch/tests/test-cluster-health.sh (updated version)

**Checkpoint**: All user stories independently functional - complete monitoring solution deployed

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, validation, and production readiness improvements

- [ ] T051 [P] Create README.md in opensearch/ directory documenting directory structure and script purposes
- [ ] T052 [P] Add inline documentation to all shell scripts (header comments explaining purpose, parameters, dependencies)
- [ ] T053 Validate quickstart.md end-to-end: follow all 7 steps from clean state, verify success
- [ ] T054 [P] Create troubleshooting guide additions for quickstart.md (common errors: port conflicts, memory limits, disk space)
- [ ] T055 [P] Update main project README.md with OpenSearch setup instructions and link to quickstart
- [ ] T056 Create test-all.sh script in opensearch/tests/test-all.sh (runs all integration tests, reports pass/fail summary)
- [ ] T057 Verify all Makefile targets work: test each make command, document expected output
- [ ] T058 [P] Add environment variable documentation to .env.example (OPENSEARCH_HEAP, OPENSEARCH_PORT, DASHBOARDS_PORT)
- [ ] T059 Code review: verify all scripts have proper error handling, use set -e for fail-fast
- [ ] T060 Final validation: run complete workflow (make start-opensearch, create-indices, load-demo-data, run-demo-queries, check all tests pass)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - **User Story 1 (P1)**: Can start after Foundational - No dependencies on other stories
  - **User Story 2 (P2)**: Can start after Foundational - Requires US1 indices to exist for data loading
  - **User Story 3 (P3)**: Can start after Foundational - Independent of US1 and US2
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start immediately after Foundational (Phase 2) - Creates indices
- **User Story 2 (P2)**: Depends on US1 indices existing for demo data loading - Can run after US1 checkpoint
- **User Story 3 (P3)**: Can start after Foundational - Works independently, no data dependency

### Within Each User Story

- **US1**: Tests first (T013-T015) → Index mappings parallel (T016-T018) → Create script (T019) → Integration (T020-T022)
- **US2**: Test first (T023) → Data generation parallel (T024-T026) → Load script (T027-T028) → Query scripts parallel (T029-T033) → Run script (T034-T035) → Validation (T036-T038)
- **US3**: Test update (T039) → Monitoring scripts parallel (T041-T043) → Makefile targets parallel (T044-T045) → Documentation parallel (T046-T047) → Validation (T048-T050)

### Parallel Opportunities

**Phase 1 (Setup)**: All 3 tasks can run in parallel (T001, T002, T003 - different directories)

**Phase 2 (Foundational)**: Many tasks parallelizable:
- T005-T007 (OpenSearch services + config files)
- T009-T011 (Makefile targets - different targets)

**Phase 3 (US1)**:
- Tests T013-T015 (different test files)
- Mappings T016-T018 (different JSON files)

**Phase 4 (US2)**:
- Data generation T024-T026 (different data files)
- Query scripts T029-T033 (different query files)

**Phase 5 (US3)**:
- Monitoring scripts T042-T043
- Makefile targets T044-T045
- Documentation T046-T047

**Phase 6 (Polish)**: Most tasks parallelizable (T051, T052, T054, T055, T058 - different files)

---

## Parallel Example: User Story 1

```bash
# Launch all integration tests for User Story 1 together (write first, ensure FAIL):
Task: "Create test-index-creation.sh in opensearch/tests/test-index-creation.sh"
Task: "Create test-document-insertion.sh in opensearch/tests/test-document-insertion.sh"
Task: "Create test-cluster-health.sh in opensearch/tests/test-cluster-health.sh"

# Launch all index mapping files together:
Task: "Create videos-index.json mapping in opensearch/mappings/videos-index.json"
Task: "Create users-index.json mapping in opensearch/mappings/users-index.json"
Task: "Create comments-index.json mapping in opensearch/mappings/comments-index.json"
```

## Parallel Example: User Story 2

```bash
# Launch all data generation scripts together:
Task: "Create generate-videos-data.sh script in opensearch/demo-data/generate-videos-data.sh"
Task: "Create generate-users-data.sh script in opensearch/demo-data/generate-users-data.sh"
Task: "Create generate-comments-data.sh script in opensearch/demo-data/generate-comments-data.sh"

# Launch all query scripts together:
Task: "Create relevance-search.sh in opensearch/queries/relevance-search.sh"
Task: "Create recency-sort.sh in opensearch/queries/recency-sort.sh"
Task: "Create popularity-sort.sh in opensearch/queries/popularity-sort.sh"
Task: "Create hybrid-ranking.sh in opensearch/queries/hybrid-ranking.sh"
Task: "Create filtered-aggregations.sh in opensearch/queries/filtered-aggregations.sh"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T003)
2. Complete Phase 2: Foundational (T004-T012) - **CRITICAL** - blocks all stories
3. Complete Phase 3: User Story 1 (T013-T022)
4. **STOP and VALIDATE**: Test User Story 1 independently
   - Run make start-opensearch
   - Run make create-indices
   - Verify all 3 indices exist with correct mappings
   - Run all US1 integration tests
5. Deploy/demo OpenSearch infrastructure ready for CDC consumer

**MVP Scope**: After US1, you have a working OpenSearch cluster with indices ready to receive CDC data from feature 004 consumer.

### Incremental Delivery

1. **Setup + Foundational** (T001-T012) → OpenSearch cluster deployable
2. **+ User Story 1** (T013-T022) → Indices configured ✅ **MVP** - Consumer can start indexing
3. **+ User Story 2** (T023-T038) → Demo queries working → Can showcase search capabilities
4. **+ User Story 3** (T039-T050) → Monitoring active → Production-ready observability
5. **+ Polish** (T051-T060) → Documentation complete → Handoff ready

Each increment adds value without breaking previous functionality.

### Parallel Team Strategy

With multiple developers:

1. **Team completes Setup + Foundational together** (T001-T012)
2. **Once Foundational is done**, split work:
   - **Developer A**: User Story 1 (T013-T022) - Index configuration
   - **Developer B**: User Story 2 (T023-T038) - Demo queries (starts after A finishes indices)
   - **Developer C**: User Story 3 (T039-T050) - Monitoring (can work in parallel)
3. **Merge and integrate**: Each story complete independently
4. **Team completes Polish together** (T051-T060)

---

## Task Summary

**Total Tasks**: 60

**Breakdown by Phase**:
- Phase 1 (Setup): 3 tasks
- Phase 2 (Foundational): 9 tasks
- Phase 3 (User Story 1 - P1): 10 tasks
- Phase 4 (User Story 2 - P2): 16 tasks
- Phase 5 (User Story 3 - P3): 12 tasks
- Phase 6 (Polish): 10 tasks

**Breakdown by User Story**:
- User Story 1 (P1): 10 tasks (T013-T022) - Deploy indices
- User Story 2 (P2): 16 tasks (T023-T038) - Demo queries
- User Story 3 (P3): 12 tasks (T039-T050) - Monitoring

**Parallel Opportunities**: 31 tasks marked [P] can run in parallel within their phase

**Independent Test Criteria**:
- **US1**: Run make create-indices, verify 3 indices with correct mappings
- **US2**: Run make load-demo-data && make run-demo-queries, verify 4+ query strategies work
- **US3**: Access Dashboards at localhost:5601, run make status-opensearch, verify metrics displayed

**MVP Scope (User Story 1)**: 22 tasks (Setup + Foundational + US1) = Minimum viable OpenSearch deployment

---

## Notes

- All tasks follow format: `- [ ] [ID] [P?] [Story?] Description with file path`
- [P] tasks work on different files, can execute in parallel
- [US1], [US2], [US3] labels map tasks to user stories from spec.md
- Each user story independently completable and testable per spec.md requirements
- Integration tests mandatory per constitution Principle III (NON-NEGOTIABLE)
- Write tests FIRST, ensure they FAIL, then implement
- Commit after each task or logical group
- Stop at checkpoints to validate stories independently
- Shell script best practices: use `set -e` for fail-fast, add error handling, document parameters
