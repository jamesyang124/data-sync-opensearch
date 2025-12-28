# Quickstart: Test Data Service

**Prerequisites**:
- Go 1.24+
- Docker & Docker Compose
- PostgreSQL (running via project's docker-compose)
- k6 (for load testing)

## Build

```bash
# Build binary
make build

# Build docker image
make docker-build
```

## Run Locally

1. **Ensure Postgres is running**:
   ```bash
   cd ../..
   make up-postgres
   ```

2. **Run Service**:
   ```bash
   export PRODUCER_DB_HOST=localhost
   export PRODUCER_DB_USER=postgres
   export PRODUCER_DB_PASSWORD=postgres
   export PRODUCER_DB_NAME=opensearch_demo

   ./bin/producer serve --port 8080
   ```

## Run Load Tests (k6)

1. **Start Producer Server**:
   ```bash
   docker-compose up -d producer
   ```

2. **Run k6 Script**:
   ```bash
   # Requires k6 installed locally or via docker
   k6 run tests/k6/load-test.js
   ```

## Development

```bash
# Run tests
make test

# Run linter
make lint
```
