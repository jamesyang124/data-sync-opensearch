# Implementation Plan: Golang CDC Consumer Application

**Branch**: `004-golang-consumer` | **Date**: 2025-12-25 | **Spec**: [spec.md](spec.md)

## Summary

Build Golang consumer application that reads CDC events from Kafka topics (dbserver.public.videos, users, comments), transforms to OpenSearch documents, indexes with idempotent upserts, handles failures with retries and dead letter queue, and exposes health/metrics endpoints.

**Technical Approach**: Golang with Sarama Kafka client (or Watermill), opensearch-go client, goroutine worker pool for concurrency, structured JSON logging, HTTP server for health checks, Docker deployment.

## Technical Context

**Language/Version**: Golang 1.21+
**Primary Dependencies**: shopify/sarama (Kafka client), opensearch-project/opensearch-go (OpenSearch client), gorilla/mux or net/http (HTTP endpoints)
**Storage**: No local storage (stateless consumer, offsets in Kafka)
**Testing**: Unit tests for transformation logic, integration tests for end-to-end pipeline
**Target Platform**: Docker container (Linux amd64)
**Project Type**: Single microservice (background consumer)
**Performance Goals**: 100 events/sec sustained throughput, <10s end-to-end latency (DB write → OpenSearch indexed)
**Constraints**: Single instance for development (no horizontal scaling yet)
**Scale/Scope**: 3 Kafka topics consumed, 3 OpenSearch indices targeted

## Constitution Check

✅ **ALL GATES PASSED**

- Plugin Architecture: Transformation logic per table type (extensible for new tables)
- Event-Driven Integration: Consumes Kafka events, produces OpenSearch indexes (**Kafka** → Consumer → **OpenSearch**)
- Integration Testing: End-to-end pipeline test (PostgreSQL write → OpenSearch read)
- Observability: Structured JSON logs with correlation IDs, health/metrics HTTP endpoints
- Docker-First: Deployed as Docker container

## Project Structure

```text
consumer/
├── cmd/
│   └── consumer/
│       └── main.go                    # Application entry point
├── internal/
│   ├── config/
│   │   └── config.go                  # Environment variable loading
│   ├── kafka/
│   │   ├── consumer.go                # Sarama consumer group setup
│   │   └── handler.go                 # Message handler implementation
│   ├── opensearch/
│   │   ├── client.go                  # OpenSearch client wrapper
│   │   └── indexer.go                 # Bulk indexing logic
│   ├── transform/
│   │   ├── video.go                   # CDC → Video document
│   │   ├── user.go                    # CDC → User document
│   │   └── comment.go                 # CDC → Comment document
│   ├── health/
│   │   └── server.go                  # HTTP health/metrics server
│   └── logger/
│       └── logger.go                  # Structured logging setup
├── pkg/
│   └── models/
│       └── cdc_event.go               # CDC event struct
├── tests/
│   ├── unit/
│   │   └── transform_test.go          # Transformation unit tests
│   └── integration/
│       └── pipeline_test.go           # End-to-end pipeline test
├── Dockerfile                         # Multi-stage build
├── go.mod                             # Dependencies
└── Makefile                           # Build, test, run targets

docker-compose.yml                     # Add consumer service
tests/consumer/            # Integration tests
```
