# Quickstart Guide: OpenSearch Configuration

**Feature**: 005-opensearch-setup | **Date**: 2025-12-25
**Purpose**: Step-by-step guide to deploy OpenSearch, create indices, and run demo queries

## Prerequisites

Before starting, ensure you have:

- ✅ Docker Desktop installed and running
- ✅ Minimum 4GB RAM available for Docker
- ✅ Minimum 10GB free disk space
- ✅ Ports 9200 and 5601 available (not in use by other services)
- ✅ `curl` and `jq` installed (for testing)
  - macOS: `brew install jq` (curl pre-installed)
  - Linux: `sudo apt-get install curl jq` or `sudo yum install curl jq`
  - Windows: Use Git Bash or WSL with curl and jq

**Check prerequisites**:
```bash
docker --version    # Should show Docker 20.10+
docker-compose --version  # Should show 1.29+ or 2.x
curl --version      # Should show curl 7.x+
jq --version        # Should show jq-1.6 or higher
```

## Step 1: Deploy OpenSearch Cluster

### 1.1 Start OpenSearch and Dashboards

```bash
# From repository root
make start-opensearch

# Or using docker-compose directly
docker-compose up -d opensearch opensearch-dashboards
```

**Expected output**:
```
Creating network "data-sync-opensearch_default" if not already created
Creating opensearch container ... done
Creating opensearch-dashboards container ... done
Waiting for OpenSearch to be ready...
✓ OpenSearch is healthy
```

### 1.2 Verify Cluster Health

```bash
# Check cluster status
make status-opensearch

# Or use curl directly
curl -s http://localhost:9200/_cluster/health | jq '.'
```

**Expected response**:
```json
{
  "cluster_name": "opensearch-dev",
  "status": "green",
  "number_of_nodes": 1,
  "number_of_data_nodes": 1,
  "active_shards": 0,
  "relocating_shards": 0,
  "initializing_shards": 0,
  "unassigned_shards": 0
}
```

✅ **Green status** = cluster is healthy and ready

### 1.3 Access OpenSearch Dashboards

Open in browser: **http://localhost:5601**

**First-time setup**:
1. Wait for Dashboards to load (may take 10-20 seconds)
2. Skip tenant selection (click "Global" or "Private")
3. Navigate to **Dev Tools** (left sidebar) for query console

---

## Step 2: Create Indices with Mappings

### 2.1 Run Index Creation Script

```bash
# Create all 3 indices (videos, users, comments)
make create-indices

# Or run script directly
./opensearch/scripts/create-indices.sh
```

**Expected output**:
```
Creating videos_index...
✓ videos_index created successfully
Creating users_index...
✓ users_index created successfully
Creating comments_index...
✓ comments_index created successfully
```

### 2.2 Verify Indices Exist

```bash
# List all indices
curl -s http://localhost:9200/_cat/indices?v

# Expected output:
# health status index          pri rep docs.count store.size
# green  open   videos_index     1   0          0        208b
# green  open   users_index      1   0          0        208b
# green  open   comments_index   1   0          0        208b
```

### 2.3 Inspect Index Mappings

```bash
# View videos_index mapping
curl -s http://localhost:9200/videos_index/_mapping | jq '.'

# Check specific field type
curl -s http://localhost:9200/videos_index/_mapping | jq '.videos_index.mappings.properties.title'
```

**Expected field types**:
- `title`: `text` with `keyword` subfield
- `view_count`: `long`
- `published_at`: `date`
- `category`: `keyword`

---

## Step 3: Load Demo Data

### 3.1 Generate and Load Sample Documents

```bash
# Load demo data into all indices
make load-demo-data

# Or run script directly
./opensearch/scripts/load-demo-data.sh
```

**Expected output**:
```
Loading demo videos (1,000 documents)...
✓ Videos loaded: 1000 indexed, 0 errors
Loading demo users (500 documents)...
✓ Users loaded: 500 indexed, 0 errors
Loading demo comments (8,500 documents)...
✓ Comments loaded: 8500 indexed, 0 errors
Total: 10,000 documents loaded in 12.3 seconds
```

### 3.2 Verify Documents Indexed

```bash
# Check document counts
curl -s http://localhost:9200/_cat/indices?v

# Expected output:
# health status index          pri rep docs.count store.size
# green  open   videos_index     1   0       1000      1.2mb
# green  open   users_index      1   0        500    512.5kb
# green  open   comments_index   1   0       8500      3.8mb
```

### 3.3 View Sample Documents

```bash
# Get random video document
curl -s http://localhost:9200/videos_index/_search?size=1 | jq '.hits.hits[0]._source'

# Get specific document by ID
curl -s http://localhost:9200/videos_index/_doc/video_12345 | jq '._source'
```

**Sample document structure**:
```json
{
  "video_id": "video_12345",
  "title": "Introduction to Machine Learning",
  "description": "Learn the fundamentals of ML...",
  "channel_id": "channel_789",
  "view_count": 1250000,
  "like_count": 35000,
  "published_at": "2024-06-15T14:30:00Z",
  "duration_seconds": 1800,
  "category": "Education",
  "tags": ["machine learning", "AI", "tutorial"]
}
```

---

## Step 4: Run Demo Queries

### 4.1 Execute All Demo Queries

```bash
# Run all 4 demo query strategies
make run-demo-queries

# Or run script directly
./opensearch/scripts/run-demo-queries.sh
```

**Expected output**:
```
=== Query 1: Text Relevance Search (BM25) ===
Query: "machine learning tutorial"
Results: 127 hits
Top result: "Introduction to Machine Learning" (score: 8.45)

=== Query 2: Recency-Based Sorting ===
Results: 1000 videos
Newest: "Advanced AI Techniques" (2024-12-20)

=== Query 3: Popularity-Based Sorting ===
Results: 1000 videos
Most viewed: "Viral Python Tutorial" (15.2M views)

=== Query 4: Hybrid Multi-Factor Ranking ===
Query: "tutorial"
Results: 340 hits
Top result combines relevance + recency + popularity
```

### 4.2 Run Individual Queries

#### Query 1: Text Relevance Search

```bash
./opensearch/queries/relevance-search.sh "machine learning"

# Or use curl with contract JSON
curl -X POST http://localhost:9200/videos_index/_search \
  -H 'Content-Type: application/json' \
  -d @specs/005-opensearch-setup/contracts/demo-query-relevance.json
```

#### Query 2: Recency-Based Sorting

```bash
./opensearch/queries/recency-sort.sh

# Or use curl
curl -X POST http://localhost:9200/videos_index/_search \
  -H 'Content-Type: application/json' \
  -d @specs/005-opensearch-setup/contracts/demo-query-recency.json
```

#### Query 3: Popularity-Based Sorting

```bash
./opensearch/queries/popularity-sort.sh

# Or use curl
curl -X POST http://localhost:9200/videos_index/_search \
  -H 'Content-Type: application/json' \
  -d @specs/005-opensearch-setup/contracts/demo-query-popularity.json
```

#### Query 4: Hybrid Multi-Factor Ranking

```bash
./opensearch/queries/hybrid-ranking.sh "tutorial"

# Or use curl
curl -X POST http://localhost:9200/videos_index/_search \
  -H 'Content-Type: application/json' \
  -d @specs/005-opensearch-setup/contracts/demo-query-hybrid.json
```

### 4.3 Understanding Query Results

**Result structure**:
```json
{
  "took": 45,  // Query execution time in milliseconds
  "hits": {
    "total": {
      "value": 127,  // Total matching documents
      "relation": "eq"
    },
    "max_score": 8.45,  // Highest relevance score
    "hits": [
      {
        "_index": "videos_index",
        "_id": "video_12345",
        "_score": 8.45,  // Relevance score for this document
        "_source": {
          "video_id": "video_12345",
          "title": "Introduction to Machine Learning",
          ...
        }
      }
    ]
  }
}
```

**Key metrics**:
- `took`: Query performance (<500ms expected per SC-003)
- `hits.total.value`: Number of matching documents
- `_score`: BM25 relevance score (higher = more relevant)

---

## Step 5: Explore with OpenSearch Dashboards

### 5.1 Open Dev Tools Console

1. Navigate to **http://localhost:5601**
2. Click **Dev Tools** in left sidebar
3. Try running queries in the console

**Example queries to try**:

```json
// Search for videos
GET /videos_index/_search
{
  "query": {
    "match": {
      "title": "python tutorial"
    }
  }
}

// Get cluster stats
GET /_cluster/stats

// View all indices
GET /_cat/indices?v

// Analyze query scoring
GET /videos_index/_search?explain=true
{
  "query": {
    "match": {
      "title": "machine learning"
    }
  },
  "size": 1
}
```

### 5.2 Create Index Pattern for Discovery

1. Go to **Management** → **Index Patterns**
2. Click **Create index pattern**
3. Enter pattern: `videos_index` (or `*_index` for all indices)
4. Click **Next step**
5. Select **published_at** as time field (or skip if not time-series data)
6. Click **Create index pattern**

### 5.3 Explore Data in Discover

1. Navigate to **Discover** (left sidebar)
2. Select `videos_index` pattern
3. View documents, apply filters, create visualizations

---

## Step 6: Integration Testing

### 6.1 Run Integration Tests

```bash
# Run all integration tests
./opensearch/tests/test-all.sh

# Or run individual tests
./opensearch/tests/test-index-creation.sh
./opensearch/tests/test-document-insertion.sh
./opensearch/tests/test-query-execution.sh
./opensearch/tests/test-cluster-health.sh
```

**Expected output**:
```
✓ Index creation test passed
✓ Document insertion test passed
✓ Query execution test passed
✓ Cluster health test passed
All integration tests passed (4/4)
```

### 6.2 Manual Test: Insert Custom Document

```bash
# Insert test video
curl -X POST http://localhost:9200/videos_index/_doc/test-video-1 \
  -H 'Content-Type: application/json' \
  -d '{
    "video_id": "test-video-1",
    "title": "My Test Video",
    "description": "Testing OpenSearch indexing",
    "channel_id": "my-channel",
    "view_count": 100,
    "like_count": 10,
    "published_at": "2024-12-25T10:00:00Z",
    "duration_seconds": 300,
    "category": "Test",
    "tags": ["test", "demo"]
  }'

# Verify document indexed
curl -s http://localhost:9200/videos_index/_doc/test-video-1 | jq '._source.title'

# Search for it
curl -X POST http://localhost:9200/videos_index/_search \
  -H 'Content-Type: application/json' \
  -d '{"query": {"match": {"title": "test"}}}'
```

---

## Step 7: Cleanup and Maintenance

### 7.1 Stop OpenSearch

```bash
# Stop containers (preserves data)
make stop-opensearch

# Or use docker-compose
docker-compose stop opensearch opensearch-dashboards
```

### 7.2 Restart OpenSearch

```bash
# Restart containers
make restart-opensearch

# Or use docker-compose
docker-compose restart opensearch opensearch-dashboards
```

### 7.3 Delete Indices (Reset State)

```bash
# Delete all indices
curl -X DELETE http://localhost:9200/videos_index
curl -X DELETE http://localhost:9200/users_index
curl -X DELETE http://localhost:9200/comments_index

# Recreate fresh indices
make create-indices
```

### 7.4 Complete Teardown

```bash
# Stop and remove containers + volumes
docker-compose down -v

# Remove OpenSearch data directory
rm -rf ./opensearch/data/
```

---

## Troubleshooting

### Issue: Port 9200 already in use

**Symptom**: `docker-compose up` fails with "port is already allocated"

**Solution**:
```bash
# Find process using port 9200
lsof -i :9200  # macOS/Linux
netstat -ano | findstr :9200  # Windows

# Kill the process or change OpenSearch port
# Edit docker-compose.yml to use different port:
# ports:
#   - "9201:9200"  # Map to 9201 instead
```

### Issue: Cluster health is yellow/red

**Symptom**: `/_cluster/health` returns `"status": "yellow"` or `"status": "red"`

**Solution**:
```bash
# Check unassigned shards
curl -s http://localhost:9200/_cat/shards?v | grep UNASSIGNED

# For single-node dev cluster, yellow is OK (no replicas)
# If red, check OpenSearch logs:
docker logs opensearch

# Common fix: Increase heap size in docker-compose.yml
# environment:
#   - "OPENSEARCH_JAVA_OPTS=-Xms2g -Xmx2g"  # Change to 4g if available
```

### Issue: Out of disk space

**Symptom**: Index creation fails with "disk threshold exceeded"

**Solution**:
```bash
# Check disk usage
curl -s http://localhost:9200/_cat/allocation?v

# Free up space by deleting old indices
curl -X DELETE http://localhost:9200/old_index_name

# Or adjust disk threshold (development only):
curl -X PUT http://localhost:9200/_cluster/settings \
  -H 'Content-Type: application/json' \
  -d '{
    "transient": {
      "cluster.routing.allocation.disk.threshold_enabled": false
    }
  }'
```

### Issue: Dashboards not loading

**Symptom**: http://localhost:5601 shows "OpenSearch Dashboards server is not ready yet"

**Solution**:
```bash
# Check Dashboards container logs
docker logs opensearch-dashboards

# Verify OpenSearch is accessible from Dashboards container
docker exec opensearch-dashboards curl http://opensearch:9200

# If connection fails, check docker network
docker network inspect data-sync-opensearch_default
```

### Issue: Demo queries return no results

**Symptom**: Queries execute but return 0 hits

**Solution**:
```bash
# Verify documents are indexed
curl -s http://localhost:9200/_cat/indices?v

# If docs.count is 0, reload demo data
make load-demo-data

# If docs.count is >0, check query syntax
# Add explain=true to see why no matches:
curl -X POST "http://localhost:9200/videos_index/_search?explain=true" \
  -H 'Content-Type: application/json' \
  -d '{"query": {"match": {"title": "test"}}}'
```

---

## Next Steps

✅ **You've successfully deployed OpenSearch!**

**What's next?**:

1. **Connect consumer application (feature 004)**:
   - Configure consumer to index CDC events to these indices
   - Test end-to-end pipeline: PostgreSQL → Debezium → Kafka → Consumer → OpenSearch

2. **Customize queries**:
   - Modify demo query contracts in `specs/005-opensearch-setup/contracts/`
   - Adjust function_score weights in hybrid ranking query
   - Add new queries for your use cases

3. **Production considerations**:
   - Enable security (TLS, authentication, RBAC)
   - Configure multi-node cluster for high availability
   - Set up monitoring (Prometheus + Grafana)
   - Implement index lifecycle management (ILM)
   - Tune performance (heap size, refresh interval, shard count)

**Documentation**:
- [spec.md](spec.md) - Feature specification
- [data-model.md](data-model.md) - Index schema details
- [research.md](research.md) - Technical decisions and alternatives
- [contracts/](contracts/) - Index mappings and query templates

**Helpful Commands**:
```bash
make help                 # List all available Makefile targets
make status-opensearch    # Check cluster health
curl http://localhost:9200/_cat/indices?v  # List indices
curl http://localhost:9200/_cat/shards?v   # View shard allocation
```
