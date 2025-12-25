# Implementation Plan: Golang CDC Consumer Application

**Branch**: `005-consumer-app` | **Date**: 2025-12-25 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/005-consumer-app/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Deploy OpenSearch cluster with pre-configured indices (videos_index, users_index, comments_index) matching PostgreSQL CDC schema, provide demo queries demonstrating 4+ ranking strategies (text relevance, recency, popularity, hybrid multi-factor scoring), and include monitoring via OpenSearch Dashboards. This completes the data sync pipeline by providing the search infrastructure target for the Golang consumer application (feature 004).

**Technical Approach**: Docker Compose deployment with OpenSearch 2.x single-node cluster, index creation scripts using OpenSearch REST API, sample data loading utilities, and documented query examples in multiple formats (curl, Query DSL JSON). Makefile targets for lifecycle management.

## Technical Context

**Language/Version**: Shell scripts (bash) for automation, JSON for index mappings and queries, Docker Compose YAML for orchestration
**Primary Dependencies**: OpenSearch 2.11+ (Docker image), OpenSearch Dashboards 2.11+ (Docker image), curl for REST API interactions
**Storage**: Docker volumes for OpenSearch data persistence, local filesystem for index mapping templates and demo query files
**Testing**: Integration tests via curl commands validating index creation, document insertion, and query execution; health check validation
**Target Platform**: Docker Desktop (macOS/Linux/Windows) for local development
**Project Type**: Infrastructure configuration (Docker services + scripts)
**Performance Goals**: Cluster startup <10 seconds, index creation <5 seconds, demo queries <500ms response time for 50K documents
**Constraints**: Single-node cluster (no distributed setup), 2GB minimum heap memory, local development only (no production hardening)
**Scale/Scope**: 3 indices, 10-50K demo documents total, 4-5 demo queries, 7 Makefile targets

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle I: Plugin Architecture ✅ PASS

**Status**: Not directly applicable - This is infrastructure configuration, not application code.

**Evaluation**: OpenSearch itself supports plugin architecture, but this feature focuses on deploying and configuring the cluster rather than building plugins. The index mappings are statically defined based on CDC schema from feature 001. Future features could add custom analyzers or plugins if needed.

**No violations**.

### Principle II: Event-Driven Integration ✅ PASS

**Status**: Compliant - OpenSearch receives documents from consumer application (feature 004) via REST API.

**Evaluation**: OpenSearch acts as the final destination in the event-driven pipeline (PostgreSQL → Debezium → Kafka → Consumer → **OpenSearch**). Documents are indexed via REST API calls from the consumer, maintaining the event-driven pattern. No direct database polling or synchronous blocking calls.

**No violations**.

### Principle III: Integration Testing (NON-NEGOTIABLE) ✅ PASS

**Status**: Compliant - Integration tests required for full pipeline validation.

**Evaluation**: Feature includes integration test requirements:
- **Index creation test**: Verify indices exist with correct mappings via `GET /_cat/indices` and `GET /videos_index/_mapping`
- **Document insertion test**: Insert sample documents and verify indexing via `POST /videos_index/_doc` and search
- **Query validation test**: Execute each demo query and verify response structure and ranking behavior
- **End-to-end pipeline test**: Combined with feature 004 consumer, test PostgreSQL → CDC → Kafka → Consumer → OpenSearch → Query flow

**Required Test Coverage** (per constitution):
- ✅ Schema changes: Test index mapping updates and dynamic field handling
- ✅ Message format: Validate consumer-generated documents match index mappings
- ✅ Error scenarios: Test disk full, malformed documents, missing indices, query timeout

**No violations**.

### Principle IV: Observability & Debugging ✅ PASS

**Status**: Compliant - OpenSearch provides built-in observability.

**Evaluation**:
- **Structured logs**: OpenSearch emits JSON logs to stdout/stderr (configurable via log4j2.properties)
- **Health endpoints**: Cluster health API (`GET /_cluster/health`), index stats (`GET /_stats`), node info
- **Monitoring UI**: OpenSearch Dashboards provides visual monitoring (cluster status, query performance, index metrics)
- **Query debugging**: Explain API (`GET /videos_index/_search?explain=true`) shows scoring details
- **Correlation IDs**: Not directly applicable to OpenSearch configuration, but consumer (feature 004) will include correlation IDs in indexed documents for tracing

**No violations**.

### Principle V: Docker-First Deployment ✅ PASS

**Status**: Compliant - All services deployed via Docker Compose.

**Evaluation**:
- **Docker Compose**: OpenSearch and OpenSearch Dashboards deployed as containers in `docker-compose.yml`
- **Volume persistence**: Data directory mounted to Docker volume for persistence across restarts
- **Environment variables**: All configuration (heap size, ports, cluster name, discovery type) via env vars
- **Single command startup**: `docker-compose up` or Makefile target brings up complete OpenSearch infrastructure
- **No manual setup**: Index creation and demo data loading automated via scripts executed in containers

**No violations**.

### Technology Constraints ✅ PASS

**Evaluation**:
- **Search Engine**: OpenSearch MUST be the target index ✅ (feature uses OpenSearch 2.x)
- **Container Orchestration**: Docker Compose for local/test ✅ (docker-compose.yml with OpenSearch services)
- **Other constraints**: Not applicable (this is infrastructure, not consumer application)

**No violations**.

### Constitution Check Summary

**Status**: ✅ **ALL GATES PASSED** - Ready for Phase 0 research.

All five core principles satisfied. Feature focuses on infrastructure deployment using Docker Compose, aligns with event-driven pipeline architecture, includes integration test requirements, provides observability via OpenSearch APIs and Dashboards, and maintains Docker-first deployment pattern.

---

### Post-Design Re-evaluation (After Phase 1)

**Date**: 2025-12-25

**Artifacts Reviewed**:
- research.md (Phase 0 research decisions)
- data-model.md (Index schema design)
- contracts/ (Index mappings and query templates)
- quickstart.md (Deployment and testing guide)

**Re-evaluation Results**:

1. **Principle I (Plugin Architecture)**: ✅ Still PASS
   - Index mappings stored as JSON configuration files (extensible)
   - Contract-based design in `contracts/` directory enables adding new indices/queries without code changes
   - Dynamic mapping support for schema evolution (documented in data-model.md)

2. **Principle II (Event-Driven Integration)**: ✅ Still PASS
   - OpenSearch REST API design maintains asynchronous event-driven pattern
   - No synchronous polling or blocking calls introduced
   - Idempotent document indexing using PostgreSQL primary keys as `_id` (data-model.md)

3. **Principle III (Integration Testing)**: ✅ Still PASS
   - Integration test structure defined in research.md (`opensearch/tests/`)
   - Quickstart.md documents manual test procedures (Step 6)
   - Contract files enable automated query validation via curl + jq

4. **Principle IV (Observability)**: ✅ Still PASS
   - OpenSearch Dashboards integration confirmed (quickstart.md Step 5)
   - Health check, metrics, and explain API documented
   - Structured JSON logs from OpenSearch (research.md Section 7)

5. **Principle V (Docker-First)**: ✅ Still PASS
   - Docker Compose deployment fully documented (research.md Section 1, quickstart.md Step 1)
   - All automation via shell scripts + Makefile targets
   - No manual setup steps required

**Conclusion**: ✅ **No constitutional violations introduced during design phase**. All five core principles remain satisfied. Design artifacts (mappings, queries, documentation) align with constitutional requirements.

## Project Structure

### Documentation (this feature)

```text
specs/005-consumer-app/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   ├── videos-index-mapping.json
│   ├── users-index-mapping.json
│   ├── comments-index-mapping.json
│   ├── demo-query-relevance.json
│   ├── demo-query-recency.json
│   ├── demo-query-popularity.json
│   └── demo-query-hybrid.json
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
# Infrastructure configuration structure
docker-compose.yml           # Add OpenSearch and Dashboards services

opensearch/
├── config/
│   ├── opensearch.yml      # OpenSearch cluster configuration
│   └── log4j2.properties   # Logging configuration
├── mappings/
│   ├── videos-index.json   # Videos index mapping template
│   ├── users-index.json    # Users index mapping template
│   └── comments-index.json # Comments index mapping template
├── scripts/
│   ├── create-indices.sh   # Script to create all indices with mappings
│   ├── load-demo-data.sh   # Script to load sample documents
│   └── run-demo-queries.sh # Script to execute demo queries
├── demo-data/
│   ├── videos.json         # Sample video documents (JSONL format)
│   ├── users.json          # Sample user documents (JSONL format)
│   └── comments.json       # Sample comment documents (JSONL format)
└── queries/
    ├── relevance-search.sh     # Text relevance BM25 query
    ├── recency-sort.sh         # Date-based sorting query
    ├── popularity-sort.sh      # Engagement-based sorting query
    ├── hybrid-ranking.sh       # Multi-factor function_score query
    └── filtered-aggregations.sh # Faceted search query

opensearch/tests/
└── opensearch/
    ├── test-index-creation.sh       # Verify indices created correctly
    ├── test-document-insertion.sh   # Verify indexing works
    ├── test-query-execution.sh      # Verify all demo queries work
    └── test-cluster-health.sh       # Verify monitoring endpoints

Makefile                    # Add OpenSearch targets
.env.example                # Add OpenSearch environment variables
```

**Structure Decision**: Infrastructure configuration approach with scripts and Docker Compose services. OpenSearch deployment follows sidecar pattern where cluster runs as separate containers alongside existing services (PostgreSQL, Debezium, Kafka). Index mappings defined as JSON templates applied via REST API during initialization. Demo queries provided as reusable shell scripts wrapping curl commands. This structure supports easy addition of new indices or queries without modifying core application code.

## Complexity Tracking

**No constitutional violations** - No entries required.

All constitutional principles satisfied without exceptions or workarounds.
