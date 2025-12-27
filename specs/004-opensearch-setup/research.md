# Research: OpenSearch Setup

**Feature**: 004-opensearch-setup | **Date**: 2025-12-25
**Purpose**: Technical research and decision documentation for OpenSearch configuration

## Overview

This document consolidates research findings for deploying OpenSearch cluster with pre-configured indices, demo data, and query examples. All technical decisions documented here support the infrastructure deployment specified in [spec.md](spec.md).

## Research Areas

### 1. OpenSearch Deployment Strategy

**Decision**: Use official OpenSearch Docker images with Docker Compose orchestration

**Rationale**:
- **Official support**: `opensearchproject/opensearch:2.11.0` image is maintained by OpenSearch project with regular security updates
- **Single-node simplicity**: Development mode (`discovery.type=single-node`) eliminates need for multi-node coordination
- **Quick startup**: Single container deployment achieves <10 second startup (meets SC-006)
- **Persistence**: Named Docker volumes provide data persistence across container restarts
- **Environment configuration**: All settings configurable via environment variables (heap size, ports, cluster name)

**Alternatives Considered**:
- **Binary installation**: Rejected - requires manual setup, platform-specific steps, harder to reproduce across dev machines
- **Kubernetes**: Rejected - overkill for local development, adds complexity, requires K8s cluster
- **Managed service (AWS OpenSearch)**: Rejected - increases cost, requires AWS account, not suitable for local development

**Best Practices Applied**:
- Use specific version tags (2.11.0) not `latest` for reproducibility
- Mount configuration files as volumes rather than building custom images
- Set memory limits to prevent host resource exhaustion
- Use health checks to ensure container readiness before dependent services start

**References**:
- OpenSearch Docker Installation Guide: https://opensearch.org/docs/latest/install-and-configure/install-opensearch/docker/
- Docker Compose best practices: https://docs.docker.com/compose/production/

---

### 2. Index Mapping Design

**Decision**: Define explicit static mappings for all three indices with appropriate field types and analyzers

**Rationale**:
- **Type safety**: Explicit mappings prevent dynamic mapping errors (e.g., numeric stored as text)
- **Search quality**: Text fields configured with standard analyzer for tokenization and stemming
- **Query performance**: Keyword fields for exact match enable efficient filtering without analysis overhead
- **Document ID consistency**: Using `_id` field matching PostgreSQL primary keys enables idempotent upserts from consumer
- **Future-proof**: Static mappings with `dynamic: true` allow schema evolution for new fields while enforcing types for known fields
- **Change ordering**: `updated_at` stored as `date` supports optimistic conflict checks in the consumer for out-of-order CDC events

**Alternatives Considered**:
- **Fully dynamic mapping**: Rejected - risk of type conflicts (e.g., "123" indexed as text vs number), no control over analyzers
- **Strict mode (`dynamic: strict`)**: Rejected - too restrictive, would break on schema evolution, requires mapping updates for every new field

**Field Type Decisions**:

| Field Type | Use Case | Rationale |
|------------|----------|-----------|
| `text` | Searchable content (title, description, comment_text) | Full-text search with tokenization, supports BM25 relevance scoring |
| `keyword` | Exact match (video_id, user_id, category, sentiment) | No analysis, efficient filtering/sorting/aggregations, low memory |
| `text` with `keyword` subfield | Hybrid (username, channel_name, tags) | Supports both full-text search and exact match via `.keyword` subfield |
| `long` | Large numbers (view_count, like_count, subscriber_count) | 64-bit integer for high values, efficient range queries and sorting |
| `integer` | Small numbers (duration_seconds, comment like_count) | 32-bit integer sufficient for smaller ranges, saves memory |
| `date` | Timestamps (published_at, created_at, updated_at, posted_at) | ISO 8601 format, supports date math and range queries |
| `boolean` | Flags (verified) | Single bit storage, efficient filtering |

**Analyzer Configuration**:
- **Standard analyzer**: Default for English text (tokenization + lowercasing + stop words)
- **Justification**: YouTube comment data from Hugging Face dataset is English language (A-011 in spec)
- **Future enhancement**: Could add language detection and multi-language analyzers if needed

**CDC Timestamp Fields**:
- **`created_at`**: Captures initial row creation for analytics and lifecycle use cases
- **`updated_at`**: Used by the consumer to skip stale updates when CDC events arrive out of order

**Best Practices Applied**:
- Enable `_source` field (default) for document retrieval and reindexing
- Set `index: true` (default) for searchable fields
- Use `store: false` (default) to reduce storage (retrieve from `_source` instead)
- Configure `norms: false` for fields not needing scoring (exact match keywords)

**References**:
- OpenSearch Mapping Documentation: https://opensearch.org/docs/latest/field-types/
- Analyzers and Tokenizers: https://opensearch.org/docs/latest/analyzers/

---

### 3. Demo Query Ranking Strategies

**Decision**: Implement 4 core query strategies using OpenSearch Query DSL with function_score for hybrid ranking

**Rationale**:
- **Query DSL flexibility**: JSON-based query language supports all ranking strategies without custom code
- **function_score power**: Enables combining multiple scoring factors (relevance, recency, popularity) with configurable weights
- **Standard patterns**: BM25 relevance, field sorting, and function scoring are well-documented OpenSearch features
- **Demo quality**: Diverse strategies showcase search capabilities and validate index design

**Strategy Implementations**:

#### Strategy 1: Text Relevance (BM25)
**Query Type**: `match` or `multi_match`
**Implementation**:
```json
{
  "query": {
    "multi_match": {
      "query": "machine learning tutorial",
      "fields": ["title^2", "description", "tags"],
      "type": "best_fields"
    }
  }
}
```
**Rationale**:
- `multi_match` searches across multiple fields
- `title^2` boost makes title matches score higher than description
- `best_fields` type uses highest scoring field (vs `most_fields` which sums scores)

#### Strategy 2: Recency-Based Sorting
**Query Type**: `match_all` with `sort`
**Implementation**:
```json
{
  "query": { "match_all": {} },
  "sort": [
    { "published_at": { "order": "desc" } }
  ]
}
```
**Rationale**: Simple field-based sorting, no scoring needed, fastest query type

#### Strategy 3: Popularity-Based Sorting
**Query Type**: `match_all` with `sort` on engagement metrics
**Implementation**:
```json
{
  "query": { "match_all": {} },
  "sort": [
    { "view_count": { "order": "desc" } },
    { "published_at": { "order": "desc" } }
  ]
}
```
**Rationale**: Multiple sort fields for tie-breaking (secondary sort by recency)

#### Strategy 4: Hybrid Multi-Factor Ranking
**Query Type**: `function_score` with gaussian decay and field value factor
**Implementation**: See example in spec.md lines 247-278
**Rationale**:
- **Gaussian decay on date**: Recent documents boosted with configurable decay curve (`scale: 30d` means 50% score at 30 days old)
- **Field value factor on views**: Logarithmic scaling (`log1p`) prevents high view counts from dominating score
- **Weights**: Balance between relevance, recency, and popularity
- **score_mode: sum**: Combine function scores additively
- **boost_mode: sum**: Add function scores to query score (vs multiply which can zero out relevance)

**Alternatives Considered**:
- **Learning-to-rank (LTR)**: Rejected - requires training data, model deployment, adds complexity beyond demo scope
- **Script scoring**: Rejected - slower than function_score, requires enabling scripting (security concern)
- **Custom similarity**: Rejected - BM25 is industry standard, customization not needed for demo

**Best Practices Applied**:
- Use `explain: true` parameter during development to understand scoring
- Configure decay functions with realistic scale values (30d for recency = 1 month decay)
- Apply `log1p` modifier to view counts to prevent score explosion on viral videos
- Set explicit weights to make scoring transparent and tunable

**References**:
- OpenSearch Query DSL: https://opensearch.org/docs/latest/query-dsl/
- Function Score Query: https://opensearch.org/docs/latest/query-dsl/compound/function-score/

---

### 4. Demo Data Generation

**Decision**: Generate synthetic demo data programmatically based on Hugging Face dataset schema

**Rationale**:
- **Realistic data**: Match actual YouTube comment dataset structure (video metadata, user info, comments with sentiment)
- **Volume control**: Generate 10K-50K documents to test indexing performance (meets SC-008: load in <30s)
- **Relationship integrity**: Ensure foreign key relationships (video_id, user_id in comments) reference valid entities
- **Sentiment distribution**: Include mix of positive, negative, neutral comments for faceted search demos

**Data Generation Approach**:

1. **Videos (1,000 documents)**:
   - Generate realistic titles using keyword combinations (e.g., "Machine Learning Tutorial", "Python Basics")
   - Random view counts (1K-10M using log distribution for realism)
   - Published dates spanning last 2 years (for recency testing)
   - Categories from standard YouTube set (Education, Entertainment, Technology, etc.)

2. **Users (500 documents)**:
   - Unique usernames and channel names
   - Subscriber counts (100-1M using log distribution)
   - Created dates (2010-2024 for established channels)
   - Random verified status (10% verified)

3. **Comments (8,500 documents)**:
   - Link to videos (each video gets 5-15 comments)
   - Link to users (users post multiple comments)
   - Comment text from common patterns (praises, questions, criticisms)
   - Sentiment labels (60% positive, 25% neutral, 15% negative - typical YouTube distribution)
   - Like counts (0-1000 using exponential distribution)
   - Posted dates relative to video published date

**Format**: JSONL (newline-delimited JSON) for bulk indexing via `_bulk` API

**Alternatives Considered**:
- **Use real Hugging Face dataset**: Rejected - privacy concerns, large download, complexity of extracting subset
- **Manually crafted examples**: Rejected - doesn't scale to 10K documents, not realistic for performance testing
- **Third-party fake data library (Faker)**: Considered - could use for future enhancement, but simple generation script sufficient for now

**Best Practices Applied**:
- Use JSONL format for efficient bulk indexing (one document per line)
- Include `_id` field in documents to enable idempotent reloading
- Generate data with variety to test all query strategies (recent/old, popular/unpopular, etc.)
- Create reproducible data generation script (seeded random for consistent results)

**References**:
- OpenSearch Bulk API: https://opensearch.org/docs/latest/api-reference/document-apis/bulk/
- JSONL specification: https://jsonlines.org/

---

### 5. Integration Testing Strategy

**Decision**: Shell script-based integration tests using curl and jq for JSON validation

**Rationale**:
- **Simplicity**: Shell scripts run anywhere (macOS, Linux, CI/CD) without language dependencies
- **curl availability**: Pre-installed on all platforms, direct REST API testing
- **jq for validation**: Parse JSON responses and assert field values
- **Fast feedback**: Tests run in seconds, suitable for TDD workflow
- **Constitution compliance**: Meets Principle III requirement for integration tests

**Test Coverage**:

1. **Index Creation Test** (`test-index-creation.sh`):
   ```bash
   # Verify all 3 indices exist
   curl -s http://localhost:9200/_cat/indices | grep videos_index
   curl -s http://localhost:9200/_cat/indices | grep users_index
   curl -s http://localhost:9200/_cat/indices | grep comments_index

   # Verify videos_index mapping
   curl -s http://localhost:9200/videos_index/_mapping | jq '.videos_index.mappings.properties.title.type' | grep "text"
   curl -s http://localhost:9200/videos_index/_mapping | jq '.videos_index.mappings.properties.view_count.type' | grep "long"
   ```

2. **Document Insertion Test** (`test-document-insertion.sh`):
   ```bash
   # Insert test video document
   curl -X POST http://localhost:9200/videos_index/_doc/test-video-1 -H 'Content-Type: application/json' -d '{...}'

   # Verify document indexed
   curl -s http://localhost:9200/videos_index/_doc/test-video-1 | jq '._source.title'

   # Search for document
   curl -X POST http://localhost:9200/videos_index/_search -H 'Content-Type: application/json' -d '{"query":{"match":{"title":"test"}}}'
   ```

3. **Query Execution Test** (`test-query-execution.sh`):
   ```bash
   # Test relevance query
   response=$(./opensearch/queries/relevance-search.sh "tutorial")
   echo "$response" | jq '.hits.total.value' | grep -v "^0$"  # Ensure results found

   # Test hybrid ranking
   ./opensearch/queries/hybrid-ranking.sh "machine learning" | jq '.hits.hits[0]._score > 0'
   ```

4. **Cluster Health Test** (`test-cluster-health.sh`):
   ```bash
   # Verify green status
   curl -s http://localhost:9200/_cluster/health | jq '.status' | grep "green"

   # Verify node count
   curl -s http://localhost:9200/_cluster/health | jq '.number_of_nodes' | grep "1"
   ```

**Alternatives Considered**:
- **Python pytest with opensearch-py**: Rejected - adds Python dependency, slower startup, overkill for API testing
- **Postman/Newman**: Rejected - requires Postman collection export, less scriptable, another tool to learn
- **Go integration tests**: Rejected - requires Go compilation, heavier than shell scripts for simple API tests

**Best Practices Applied**:
- Use `-s` flag with curl to suppress progress output (cleaner test output)
- Check HTTP status codes with `-w "%{http_code}"` to catch API errors
- Use `jq -e` for assertion failures (exits non-zero if query returns null)
- Include test setup/teardown (create test data, clean up after)

**References**:
- curl manual: https://curl.se/docs/manpage.html
- jq manual: https://jqlang.github.io/jq/manual/

---

### 6. Makefile Target Design

**Decision**: Add 7 OpenSearch-related targets to existing Makefile for lifecycle management

**Rationale**:
- **Consistency**: Matches existing Makefile pattern from features 001-004
- **Discoverability**: `make help` lists all available commands
- **Simplicity**: Single command entry points for common operations
- **Idempotency**: Targets can be run multiple times safely

**Targets to Implement**:

```makefile
.PHONY: start-opensearch
start-opensearch:  ## Start OpenSearch and Dashboards containers
	docker-compose up -d opensearch opensearch-dashboard
	@echo "Waiting for OpenSearch to be ready..."
	@./opensearch/scripts/wait-for-health.sh

.PHONY: stop-opensearch
stop-opensearch:  ## Stop OpenSearch containers
	docker-compose stop opensearch opensearch-dashboard

.PHONY: restart-opensearch
restart-opensearch: stop-opensearch start-opensearch  ## Restart OpenSearch

.PHONY: status-opensearch
status-opensearch:  ## Check OpenSearch cluster health
	@curl -s http://localhost:9200/_cluster/health | jq '.'

.PHONY: create-indices
create-indices:  ## Create all indices with mappings
	@./opensearch/scripts/create-indices.sh

.PHONY: load-demo-data
load-demo-data:  ## Load demo data into indices
	@./opensearch/scripts/load-demo-data.sh

.PHONY: run-demo-queries
run-demo-queries:  ## Execute all demo queries
	@./opensearch/scripts/run-demo-queries.sh
```

**Best Practices Applied**:
- Use `.PHONY` to prevent conflicts with files named same as targets
- Add `##` comments for `make help` documentation
- Chain dependent targets (restart = stop + start)
- Include wait-for-health script to ensure OpenSearch ready before index creation

**References**:
- GNU Make manual: https://www.gnu.org/software/make/manual/

---

### 7. OpenSearch Dashboards Configuration

**Decision**: Deploy OpenSearch Dashboards as companion container for visual monitoring and query development

**Rationale**:
- **Developer experience**: Visual interface faster than curl for exploratory queries
- **Query development**: Dev Tools console with autocomplete and syntax highlighting
- **Index management**: Visual index settings and mapping viewer
- **Debugging**: Explain API integration shows scoring breakdown
- **Constitution compliance**: Meets Principle IV observability requirement

**Configuration**:
```yaml
opensearch-dashboard:
  image: opensearchproject/opensearch-dashboards:2.11.0
  ports:
    - "5601:5601"
  environment:
    - OPENSEARCH_HOSTS=http://opensearch:9200
    - DISABLE_SECURITY_DASHBOARDS_PLUGIN=true  # Development only
  depends_on:
    - opensearch
```

**Key Features to Document**:
- **Dev Tools**: Query console at http://localhost:5601/app/dev_tools#/console
- **Index Management**: View/edit indices at http://localhost:5601/app/management/opensearch-dashboards/indexPatterns
- **Discover**: Explore documents at http://localhost:5601/app/discover
- **Cluster Health**: Monitor at http://localhost:5601/app/management/opensearch-dashboards/cluster

**Alternatives Considered**:
- **Kibana (Elasticsearch UI)**: Rejected - not compatible with OpenSearch 2.x
- **Grafana with OpenSearch plugin**: Rejected - heavier setup, focused on metrics not query development
- **Custom admin UI**: Rejected - massive scope increase, Dashboards provides everything needed

**Best Practices Applied**:
- Disable security plugin for local development (simplifies setup)
- Use `depends_on` to ensure OpenSearch starts first
- Expose standard port 5601 for consistency

**References**:
- OpenSearch Dashboards: https://opensearch.org/docs/latest/dashboards/

---

## Technology Stack Summary

| Component | Version/Tool | Purpose |
|-----------|--------------|---------|
| **OpenSearch** | 2.11.0 | Search engine cluster (single-node dev mode) |
| **OpenSearch Dashboards** | 2.11.0 | Visual monitoring and query development UI |
| **Docker Compose** | 3.8+ | Container orchestration |
| **Bash** | 4.0+ | Automation scripts (index creation, data loading, queries) |
| **curl** | 7.0+ | REST API interaction |
| **jq** | 1.6+ | JSON parsing and validation in tests |
| **Make** | 4.0+ | Task automation via Makefile |

---

## Dependencies on Other Features

### Feature 001 (PostgreSQL Datasource)
- **Dependency**: Index mappings must match PostgreSQL normalized schema (3 tables)
- **Impact**: Field names and types derived from videos/users/comments table structure
- **Status**: Spec reviewed, mappings aligned

### Feature 005 (Golang Consumer)
- **Dependency**: Consumer will index documents using REST API
- **Impact**: Document `_id` must match PostgreSQL primary keys for idempotent upserts
- **Status**: Coordination needed on document ID format and error handling

---

## Open Questions / Risks

### None Remaining

All technical decisions documented above. No NEEDS CLARIFICATION markers from Technical Context section.

**Risk Mitigation**:
- **Disk space**: Document minimum 10GB free space requirement in README
- **Memory**: Set explicit heap limits in docker-compose.yml to prevent host OOM
- **Port conflicts**: Document required ports (9200, 5601) and how to change via env vars

---

## Implementation Readiness

✅ **All research complete** - Ready for Phase 1 (data model and contracts generation).

**Next Steps**:
1. Generate data-model.md (index schema documentation)
2. Generate contracts/ (JSON mapping files and query templates)
3. Generate quickstart.md (getting started guide)
4. Update agent context with OpenSearch technology stack
