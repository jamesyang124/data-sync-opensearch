# Feature Specification: Test Data Service

**Feature Branch**: `006-producer-app`
**Created**: 2025-12-28
**Status**: Draft
**Input**: User description: "producer-app" (Refactored to API-only)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - REST API for Data Management (Priority: P1)

As a developer, I need a lightweight REST API service that wraps PostgreSQL operations (Insert, Update, Delete), so I can easily seed data and trigger CDC events using external tools (like k6 or curl) without direct database access.

**Why this priority**: Decouples the data generation logic (which changes often) from the database insertion logic (which is stable).

**Independent Test**: Can be tested by sending HTTP POST/PUT/DELETE requests to the service and verifying changes in PostgreSQL.

**Acceptance Scenarios**:
1.  **Given** the service is running, **When** I send `POST /api/v1/users` with valid JSON, **Then** a new user is inserted into the DB and the ID is returned.
2.  **Given** an existing user, **When** I send `PUT /api/v1/users/{id}` with updated fields, **Then** the DB record is updated.
3.  **Given** an existing user, **When** I send `DELETE /api/v1/users/{id}`, **Then** the record is removed from the DB.

---

### User Story 2 - High-Throughput Load Testing Support (Priority: P2)

As a QA engineer, I need the API service to handle high concurrency (e.g., 500+ requests/sec) with low latency, so I can use k6 to simulate realistic production traffic and stress-test the downstream CDC pipeline.

**Why this priority**: The primary goal is validating the CDC pipeline under load. The API must not be the bottleneck.

**Independent Test**: Run a k6 benchmark targeting 500 RPS and ensure 99% of requests return 2xx codes with latency < 50ms.

**Acceptance Scenarios**:
1.  **Given** k6 sends 500 requests/second, **When** the service processes them, **Then** it handles the load without crashing or exhausting DB connections.
2.  **Given** the DB becomes slow, **When** the internal connection pool fills up, **Then** the API returns 503 Service Unavailable (backpressure) instead of hanging indefinitely.

---

### Edge Cases

- **Invalid JSON**: Return 400 Bad Request.
- **Constraint Violations**: Return 409 Conflict (e.g., duplicate primary key or missing foreign key).
- **DB Down**: Return 500/503.
- **Missing Entity**: Return 404 Not Found for Update/Delete.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Application MUST expose REST endpoints for Users, Videos, and Comments entities.
- **FR-002**: Application MUST support POST (Create), PUT (Update), and DELETE (Remove) operations.
- **FR-003**: Application MUST respect foreign key relationships (return error if child insert references missing parent).
- **FR-004**: Application MUST load database connection settings from environment variables.
- **FR-005**: Application MUST handle database errors and map them to appropriate HTTP status codes.
- **FR-006**: Application MUST expose a `/health` endpoint for readiness checks.
- **FR-007**: Application MUST expose a `/metrics` endpoint (Prometheus) tracking request counts and latency.

### Key Entities

- **API Server**: HTTP server (Chi) handling routing and middleware.
- **Database Service**: Wrapper around `pgx` pool managing transactions and query execution.
- **Domain Models**: Go structs representing the DB schema for JSON marshalling/unmarshalling.
- **Configuration**: Env vars for DB connection and Server port.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Service sustains 500 requests/sec with <50ms p95 latency (excluding DB insertion time).
- **SC-002**: Generated events match existing PostgreSQL schema constraints.
- **SC-003**: 100% of successful API calls result in committed DB transactions.
- **SC-004**: Service handles DB connection failures gracefully with automatic retry or fast failure.

## Assumptions

- **A-001**: PostgreSQL database schema matches Feature 001.
- **A-002**: The Client (xk6) handles data generation (faker), rate limiting, and workflow logic.
- **A-003**: Service runs in the same Docker network as Postgres.

## Non-Functional Requirements

- **NFR-001**: Service should be stateless and horizontally scalable (though one instance is likely sufficient).
- **NFR-002**: Service should provide structured JSON logs for all requests.
- **NFR-003**: Service should have a graceful shutdown period to finish in-flight requests.
- **NFR-004**: No authentication or authorization is required. Security boundary is the internal Docker network (A-003); the service trusts all requests on that network.

## Clarifications

### Session 2026-02-20

- Q: Does the REST API require any form of access control? → A: No auth — internal Docker network trust only.
