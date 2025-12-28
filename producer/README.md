# Producer Service

The Producer Service is a test data generation tool for the Data Sync OpenSearch pipeline. It exposes a REST API to create, update, and delete Users and Videos in PostgreSQL, triggering CDC events.

## Features

- **REST API**: Create/Update/Delete Users, Create Videos.
- **High Performance**: Built with Go, `chi`, and `pgx`.
- **Load Testing**: Includes `k6` scripts for validating system throughput.

## Configuration

Configuration is managed via environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `PRODUCER_PORT` | HTTP Server Port | `8080` |
| `PRODUCER_METRICS_PORT` | Metrics Port | `9090` |
| `PRODUCER_LOG_LEVEL` | Log Level (debug, info) | `info` |
| `PRODUCER_DB_HOST` | Postgres Host | `localhost` |
| `PRODUCER_DB_PORT` | Postgres Port | `5432` |
| `PRODUCER_DB_USER` | Postgres User | `postgres` |
| `PRODUCER_DB_PASSWORD` | Postgres Password | `postgres` |
| `PRODUCER_DB_NAME` | Postgres Database | `opensearch_demo` |

## Running the Service

### Docker (Recommended)

```bash
# Build
make docker-build

# Run
docker run -p 8080:8080 --env-file .env producer
```

### Local Development

```bash
# Install dependencies
go mod download

# Run server
make run
```

## API Usage

### Create User
```bash
curl -X POST http://localhost:8080/api/v1/users \
  -H "Content-Type: application/json" \
  -d '{"username": "jdoe", "email": "jdoe@example.com"}'
```

### Create Video
```bash
curl -X POST http://localhost:8080/api/v1/videos \
  -H "Content-Type: application/json" \
  -d '{"user_id": "UUID...", "title": "My Video", "duration": 120}'
```

## Load Testing (k6)

The project includes `k6` scripts in `tests/k6/` to validate performance.

### Prerequisites
- Install k6: https://k6.io/docs/get-started/installation/

### Running Load Tests

1. Ensure the producer service is running.
2. Run the script:

```bash
# User Creation Load Test (50 users)
k6 run tests/k6/users_load.js

# Mixed Workload (Users + Videos)
k6 run tests/k6/mixed_load.js
```
