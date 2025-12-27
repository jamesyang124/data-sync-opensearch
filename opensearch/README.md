# OpenSearch Assets

This directory contains OpenSearch configuration, mappings, demo data generators, queries, and integration tests for the local pipeline.

## Directory Layout

- `opensearch/config/`: OpenSearch and logging configuration files.
- `opensearch/mappings/`: Index mappings aligned with CDC schema.
- `opensearch/demo-data/`: Scripts to generate demo JSONL bulk data.
- `opensearch/queries/`: Query scripts for relevance, recency, popularity, hybrid ranking, and aggregations.
- `opensearch/scripts/`: Operational scripts (health checks, index creation, demo data loading).
- `opensearch/tests/`: Integration test scripts for OpenSearch behavior.

## Common Commands

Run from repository root:

```bash
make start-opensearch
make create-indices
make load-demo-data
make run-demo-queries
make status-opensearch
```

## Environment Variables

- `OPENSEARCH_URL`: Base URL for OpenSearch (default `http://localhost:9200`)
- `OPENSEARCH_PORT`: Host port for OpenSearch (default `9200`)
- `DASHBOARDS_PORT`: Host port for Dashboards (default `5601`)
- `OPENSEARCH_HEAP`: JVM heap size (default `512m`)

## Tests

```bash
./opensearch/tests/test-all.sh
```

If a test fails, run the individual script named in the output to debug.
