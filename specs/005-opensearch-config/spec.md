# Feature Specification: OpenSearch Configuration with Demo Indices

**Feature Branch**: `005-opensearch-config`
**Created**: 2025-12-25
**Status**: Draft
**Input**: User description: "open search configuration, also prepare index for demo purpose, which would combine several ranking sorting query strategy for it"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Deploy OpenSearch with Pre-configured Indices (Priority: P1)

As a developer, I need to deploy an OpenSearch cluster with pre-configured indices matching the CDC data structure (videos, users, comments), so the consumer application has a ready target for syncing data from Kafka.

**Why this priority**: This is the foundational search infrastructure. Without OpenSearch properly deployed with appropriate index mappings, the consumer application (feature 004) cannot complete the data sync pipeline.

**Independent Test**: Can be fully tested by deploying OpenSearch, verifying indices are created with correct mappings, and inserting sample documents to confirm indexing works. Delivers immediate value by providing the search backend infrastructure.

**Acceptance Scenarios**:

1. **Given** no existing OpenSearch cluster, **When** developer runs deploy command, **Then** OpenSearch container starts successfully with health check passing
2. **Given** OpenSearch is running, **When** developer checks available indices, **Then** system shows three indices (videos_index, users_index, comments_index) with appropriate mappings for each data type
3. **Given** indices are created, **When** developer inserts test document into any index, **Then** document is indexed successfully and becomes searchable within 1 second

---

### User Story 2 - Execute Demo Queries with Multiple Ranking Strategies (Priority: P2)

As a developer, I need pre-built demo queries demonstrating different ranking and sorting strategies (relevance scoring, date-based, popularity-based, hybrid combinations), so I can showcase OpenSearch search capabilities and validate the sync pipeline produces searchable results.

**Why this priority**: Essential for demonstrating value and validating search functionality, but requires data to be synced first (depends on P1 and consumer application).

**Independent Test**: Can be tested by loading sample data into indices and executing each demo query, verifying results are ranked according to the specified strategy and return relevant documents.

**Acceptance Scenarios**:

1. **Given** video index contains sample data, **When** developer executes relevance-based query for "tutorial", **Then** results are ranked by text match score with most relevant videos first
2. **Given** video index contains documents with view counts and timestamps, **When** developer executes popularity-based query, **Then** results are sorted by view count (descending) with tie-breaking by recency
3. **Given** user wants to combine multiple ranking factors, **When** developer executes hybrid query (relevance + recency + popularity), **Then** results reflect weighted combination of all three scoring factors
4. **Given** comment data is indexed, **When** developer executes date-range query with sorting, **Then** results are filtered by time window and sorted by specified field (timestamp, score, etc.)

---

### User Story 3 - Monitor Index Health and Performance (Priority: P3)

As a developer, I need to monitor OpenSearch cluster health, index statistics, and query performance metrics, so I can detect indexing issues or performance bottlenecks before they impact search availability.

**Why this priority**: Important for operational visibility but not required for basic search functionality. Developers can check logs manually as fallback.

**Independent Test**: Can be tested by accessing monitoring endpoints or dashboards and verifying they display cluster status, index metrics, and query statistics.

**Acceptance Scenarios**:

1. **Given** OpenSearch is running, **When** developer calls cluster health API, **Then** endpoint returns status (green/yellow/red), node count, and shard allocation information
2. **Given** documents are indexed, **When** developer queries index statistics, **Then** system reports document count, storage size, and indexing rate per index
3. **Given** queries are executed, **When** developer checks query performance metrics, **Then** system shows query latency distribution (p50, p95, p99) and cache hit rates

---

### Edge Cases

- What happens when OpenSearch runs out of disk space? Cluster should block new indexing operations and return clear error message; existing data remains searchable in read-only mode.
- How does system handle malformed documents that don't match index mapping? OpenSearch should reject documents with strict mapping violations or auto-adapt dynamic fields depending on configuration; errors logged with document details.
- What happens when queries are too complex or timeout? OpenSearch should cancel long-running queries after configured timeout and return partial results or error message with query context.
- How does system handle index deletion while consumer is actively writing? Consumer should detect missing index error and either auto-recreate index or move to dead letter queue depending on configuration.
- What happens when multiple clients query simultaneously with limited resources? OpenSearch should apply query throttling, prioritize by queue, and apply circuit breakers to prevent cluster instability.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST deploy OpenSearch cluster via Docker Compose with configurable heap size and volume persistence
- **FR-002**: System MUST pre-create three indices (videos_index, users_index, comments_index) with mappings matching CDC event structure from PostgreSQL tables
- **FR-003**: System MUST configure index mappings with appropriate field types (text with analyzers for searchable content, keyword for exact match, numeric for counts, date for timestamps)
- **FR-004**: System MUST provide sample documents representing realistic data for each index to enable demo query execution
- **FR-005**: System MUST include collection of demo queries demonstrating at least 4 ranking strategies: text relevance scoring, date-based sorting, popularity-based sorting (by view count or similar metric), and hybrid multi-factor scoring
- **FR-006**: System MUST configure text analyzers for search fields (standard analyzer for general text, language-specific analyzers if content language is known)
- **FR-007**: System MUST expose OpenSearch on configurable port with environment variable overrides
- **FR-008**: System MUST provide Makefile targets for OpenSearch lifecycle management (start-opensearch, stop-opensearch, restart-opensearch, status-opensearch, create-indices, load-demo-data, run-demo-queries)
- **FR-009**: System MUST configure cluster settings for development use (single-node mode, discovery disabled, memory limits appropriate for local development)
- **FR-010**: System MUST include monitoring interface (OpenSearch Dashboards or equivalent) for visual index management and query testing
- **FR-011**: System MUST document index mapping design decisions with rationale for field type choices and analyzer configurations
- **FR-012**: System MUST provide query examples in multiple formats (REST API curl commands, OpenSearch Query DSL JSON, and optionally client library code snippets)

### Key Entities

- **OpenSearch Cluster**: Distributed search and analytics engine providing full-text search, aggregations, and document indexing, configured in single-node mode for development
- **Index**: Named collection of documents with defined mapping (schema), settings (shards, replicas, analyzers), and aliases for query abstraction
- **Index Mapping**: Schema definition specifying field types, analyzers, index options, and constraints for each document field in an index
- **Document**: JSON object stored in an index, representing a synced entity (video, user, comment) with searchable fields and metadata
- **Query Strategy**: Approach for ranking and retrieving documents including text relevance (BM25 scoring), field-based sorting (date, numeric), function score (custom ranking formulas), and hybrid combinations
- **Text Analyzer**: Tokenization and normalization pipeline applied to text fields during indexing and query time, including standard analyzer, language-specific analyzers, and custom analyzers
- **Demo Query**: Pre-built search request demonstrating specific ranking strategy with sample parameters, expected result characteristics, and use case explanation
- **OpenSearch Dashboards**: Web interface for cluster management, index inspection, query testing, and visualization of search results and metrics

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developer can deploy complete OpenSearch infrastructure (cluster + indices + monitoring) in under 3 minutes using single Makefile command
- **SC-002**: All three indices are created successfully with 100% of required field mappings (video metadata, user attributes, comment content)
- **SC-003**: Demo queries execute successfully with response times under 500ms for datasets up to 50K documents
- **SC-004**: Text relevance queries return results with decreasing relevance scores demonstrating proper BM25 scoring
- **SC-005**: Hybrid ranking queries combine multiple factors (relevance + recency + popularity) with configurable weights producing different result orders
- **SC-006**: Cluster health endpoint reports green status within 10 seconds of startup
- **SC-007**: OpenSearch Dashboards loads and displays cluster status, index list, and query interface in under 5 seconds
- **SC-008**: Demo data loading completes for 10K sample documents across all indices in under 30 seconds
- **SC-009**: Documentation includes at least 4 working query examples with explanations of ranking strategy and expected results
- **SC-010**: Index mappings support full-text search, exact match filtering, range queries, and aggregations without runtime errors

## Assumptions

- **A-001**: Single-node OpenSearch cluster is sufficient for development (no high availability or distributed search required)
- **A-002**: Default OpenSearch 2.x is compatible with the data volumes and query patterns for this demo use case
- **A-003**: Index mappings can be statically defined based on PostgreSQL schema from feature 001 (videos, users, comments tables)
- **A-004**: Sample demo data can be manually crafted or extracted from subset of Hugging Face dataset for demonstration purposes
- **A-005**: Document IDs in OpenSearch will match primary key values from PostgreSQL for idempotent upserts by consumer
- **A-006**: Standard BM25 relevance scoring is acceptable (no custom similarity algorithms or learning-to-rank models required)
- **A-007**: Docker host has sufficient memory for OpenSearch heap (minimum 2GB recommended for development)
- **A-008**: Demo queries focus on common search patterns (keyword search, filtering, sorting) rather than advanced features (geospatial, machine learning)
- **A-009**: OpenSearch Dashboards accessed via localhost without authentication is acceptable for development
- **A-010**: Index refresh interval can use default settings (1 second) for near real-time search without optimization
- **A-011**: English language content is assumed for text analysis (standard analyzer appropriate for YouTube comment data)
- **A-012**: Demo queries will be provided as static examples in documentation rather than interactive query builder UI

## Index Design Recommendations

Based on the PostgreSQL schema from feature 001 and common search patterns:

### Videos Index Mapping

**Index Name**: `videos_index`

**Field Mappings**:
- **video_id**: `keyword` (exact match, document ID)
- **title**: `text` with standard analyzer (full-text search primary field)
- **description**: `text` with standard analyzer (searchable content)
- **channel_id**: `keyword` (exact match for filtering by channel)
- **view_count**: `long` (numeric for sorting and range queries)
- **like_count**: `long` (numeric for popularity scoring)
- **published_at**: `date` (timestamp for recency sorting and date range filters)
- **duration_seconds**: `integer` (numeric for filtering by video length)
- **category**: `keyword` (exact match for faceted search)
- **tags**: `text` array with keyword subfield (searchable tags + exact match)

**Index Settings**:
- **Shards**: 1 (development)
- **Replicas**: 0 (no replication needed for single-node)
- **Refresh Interval**: 1s (near real-time)

### Users Index Mapping

**Index Name**: `users_index`

**Field Mappings**:
- **user_id**: `keyword` (exact match, document ID)
- **username**: `text` with keyword subfield (searchable + exact match)
- **channel_name**: `text` with keyword subfield (searchable + exact match)
- **subscriber_count**: `long` (numeric for popularity)
- **created_at**: `date` (timestamp for account age)
- **verified**: `boolean` (filter for verified channels)
- **description**: `text` (searchable bio/about)

**Index Settings**:
- **Shards**: 1
- **Replicas**: 0
- **Refresh Interval**: 1s

### Comments Index Mapping

**Index Name**: `comments_index`

**Field Mappings**:
- **comment_id**: `keyword` (exact match, document ID)
- **video_id**: `keyword` (join to videos for filtering)
- **user_id**: `keyword` (join to users for filtering)
- **comment_text**: `text` with standard analyzer (full-text search primary field)
- **sentiment**: `keyword` (categorical: positive, negative, neutral)
- **like_count**: `integer` (numeric for sorting by engagement)
- **posted_at**: `date` (timestamp for recency)
- **parent_comment_id**: `keyword` (nullable, for threaded replies)

**Index Settings**:
- **Shards**: 1
- **Replicas**: 0
- **Refresh Interval**: 1s

## Query Strategy Recommendations

Based on common search use cases and the user request for "several ranking sorting query strategies":

### Strategy 1: Text Relevance Search (BM25)

**Use Case**: Find videos or comments by keyword with natural language ranking

**Query Pattern**: Match query with BM25 scoring on title/description/comment_text fields

**Example**: Search for "machine learning tutorial" ranked by text relevance

**Parameters**:
- **Query Type**: `match` or `multi_match`
- **Fields**: title^2 (boosted), description, tags (for videos)
- **Scoring**: Default BM25 algorithm

### Strategy 2: Recency-Based Sorting

**Use Case**: Show newest videos or latest comments first

**Query Pattern**: Match-all or filtered query with sort by date field descending

**Example**: Latest uploaded videos or recent comments in time window

**Parameters**:
- **Sort Field**: published_at (videos), posted_at (comments)
- **Sort Order**: Descending (newest first)
- **Optional Filter**: Date range (last 7 days, last month)

### Strategy 3: Popularity-Based Sorting

**Use Case**: Trending content or most engaged videos/comments

**Query Pattern**: Query with sort by engagement metrics (views, likes, subscribers)

**Example**: Most viewed videos or top-liked comments

**Parameters**:
- **Sort Field**: view_count (videos), like_count (comments/videos), subscriber_count (users)
- **Sort Order**: Descending (highest first)
- **Tie-breaking**: Secondary sort by recency for equal values

### Strategy 4: Hybrid Multi-Factor Ranking

**Use Case**: Combine relevance, recency, and popularity for balanced search results

**Query Pattern**: Function score query with multiple scoring functions weighted and combined

**Example**: Search query scored by text relevance (50%) + recency boost (25%) + popularity boost (25%)

**Parameters**:
- **Base Query**: Match query for relevance score
- **Function 1 (Recency)**: `gauss` decay function on published_at/posted_at field
- **Function 2 (Popularity)**: `field_value_factor` on view_count or like_count
- **Score Mode**: `sum` or `multiply` to combine function scores
- **Boost Mode**: `sum` to add function scores to query score
- **Weights**: Configurable per function (e.g., relevance=2.0, recency=1.0, popularity=1.0)

**Example Configuration**:
```json
{
  "query": {
    "function_score": {
      "query": { "match": { "title": "tutorial" } },
      "functions": [
        {
          "gauss": {
            "published_at": {
              "scale": "30d",
              "offset": "7d",
              "decay": 0.5
            }
          },
          "weight": 1.0
        },
        {
          "field_value_factor": {
            "field": "view_count",
            "factor": 0.0001,
            "modifier": "log1p"
          },
          "weight": 1.0
        }
      ],
      "score_mode": "sum",
      "boost_mode": "sum"
    }
  },
  "sort": ["_score"]
}
```

### Strategy 5 (Optional): Filtered Aggregations

**Use Case**: Faceted search with category/sentiment filtering and aggregation statistics

**Query Pattern**: Bool query with filters + aggregations on categorical fields

**Example**: Videos in "Education" category with view count distribution

**Parameters**:
- **Filter**: Category, verified status, sentiment
- **Aggregations**: Terms (category breakdown), stats (view count statistics), date histogram (posts over time)

## Configuration Recommendations

### Cluster Settings

- **Cluster Name**: `opensearch-dev`
- **Node Name**: `opensearch-node-01`
- **Discovery Type**: `single-node` (development mode)
- **HTTP Port**: 9200 (configurable)
- **Transport Port**: 9300
- **JVM Heap**: `-Xms2g -Xmx2g` (2GB for development, adjustable based on host memory)

### Security Settings (Development)

- **Security Plugin**: Disabled or minimal authentication for development
- **HTTPS**: Optional (can use HTTP for local development)
- **CORS**: Enabled for OpenSearch Dashboards access

### Performance Settings

- **Index Buffer Size**: Default (10% of heap)
- **Query Cache**: Enabled
- **Request Cache**: Enabled
- **Max Result Window**: 10000 (default, increase if deep pagination needed)

### Monitoring Interface

- **Recommended Tool**: OpenSearch Dashboards (official UI)
- **Port**: 5601 (configurable)
- **Features**: Dev Tools (query console), Index Management, Cluster Overview, Discover (data exploration)

## Out of Scope

- Multi-node OpenSearch cluster for high availability
- Cross-cluster search or replication
- Advanced features: machine learning, anomaly detection, k-NN search
- Custom similarity algorithms or learning-to-rank models
- Security hardening (TLS, authentication, authorization, audit logging)
- Index lifecycle management (ILM) for automated retention and rollover
- Performance benchmarking and query optimization beyond basic recommendations
- Custom OpenSearch plugins or extensions
- Snapshot and restore configuration for backups
- Ingest pipelines for complex data transformation (handled by consumer application)
- Geospatial search capabilities
- Production-grade monitoring dashboards (Grafana, Prometheus exporters)

## References

- OpenSearch Index Mapping Documentation
- OpenSearch Query DSL Reference
- BM25 Relevance Scoring Algorithm
- Function Score Query Documentation
- Docker Deployment Best Practices for OpenSearch
