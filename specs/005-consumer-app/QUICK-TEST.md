# ⚡ 5-Minute Smoke Test

**Validates all core functionality in 5 minutes**

---

## Run Tests

```bash
cd /Users/murcurial/Coding/data-sync-opensearch

# Start infrastructure (if not running)
make start

# Run smoke test (3 min)
./consumer/scripts/validate-deployment.sh

# Run E2E test (2 min)
./consumer/scripts/smoke-test.sh
```

---

## Expected Output

### validate-deployment.sh ✅

```
╔════════════════════════════════════════════════════════════╗
║  CDC Consumer Deployment Validation                        ║
╚════════════════════════════════════════════════════════════╝

=== Testing Health Endpoint Reachability ===
✓ Health endpoint is reachable at http://localhost:8080/health

=== Testing Health Endpoint Response Time ===
✓ Health endpoint responds within 1 second (127ms < 1000ms)

=== Testing Health Response Structure ===
✓ Health response contains required fields

=== Testing Kafka Connectivity ===
✓ Kafka is connected

=== Testing OpenSearch Connectivity ===
✓ OpenSearch is connected

=== Testing Metrics Endpoint ===
✓ Metrics endpoint is reachable

=== Testing Success Rate ===
✓ Success rate is healthy (99.92% >= 99%)

╔════════════════════════════════════════════════════════════╗
║  Validation Summary                                        ║
╚════════════════════════════════════════════════════════════╝

Tests passed: 18
Tests failed: 0

✓ All validation tests passed!
```

### smoke-test.sh ✅

```
╔════════════════════════════════════════════════════════════╗
║  CDC Consumer Smoke Test                                   ║
╚════════════════════════════════════════════════════════════╝

Step 1: Verifying consumer health...
✓ Consumer is healthy

Step 2: Inserting test record into PostgreSQL...
✓ Test record inserted successfully

Step 3: Waiting for CDC propagation (15 seconds)...
✓ Test record found in OpenSearch
✓ Record data is correct

Step 4: Cleaning up test record...
✓ Test record deleted from OpenSearch

Step 5: Checking consumer metrics...
✓ Success rate is healthy (>= 99%)

╔════════════════════════════════════════════════════════════╗
║  Smoke Test Summary                                        ║
╚════════════════════════════════════════════════════════════╝

✓ Consumer is processing CDC events correctly
✓ End-to-end pipeline is functional
✓ INSERT operation: Working
✓ DELETE operation: Working

The CDC consumer deployment is verified and operational.
```

---

## What This Proves

| Feature | Validated |
|---------|-----------|
| Consumer Running | ✅ Health check passes |
| Kafka Connected | ✅ Consumer receiving events |
| OpenSearch Connected | ✅ Documents being indexed |
| CDC Pipeline | ✅ PostgreSQL → Debezium → Kafka → Consumer → OpenSearch |
| INSERT Events | ✅ Records appear in OpenSearch |
| DELETE Events | ✅ Records removed from OpenSearch |
| Performance | ✅ Health responds <1s |
| Reliability | ✅ Success rate ≥99% |

---

## Next Steps

### ✅ Tests Passed → Ready to Deploy

```bash
# Mark tests complete in tasks.md
# Tasks validated: T012, T023, T024, T036, T043, T044

# Deploy to staging
docker compose --profile app up -d consumer

# Set up monitoring
./consumer/scripts/monitor-health.sh 30 &
```

### ❌ Tests Failed → Debug

```bash
# Check consumer logs
docker compose logs consumer --tail=100

# Check Debezium status
make status-cdc

# Verify Kafka topics
docker compose exec kafka kafka-topics.sh --list \
  --bootstrap-server localhost:9092

# Check OpenSearch
curl http://localhost:9200/_cluster/health | jq .
```

---

## CI/CD Integration

Add to your deployment pipeline:

```yaml
# .github/workflows/deploy.yml
jobs:
  test-and-deploy:
    steps:
      - name: Start infrastructure
        run: make start

      - name: Wait for services
        run: sleep 30

      - name: Run smoke test
        run: |
          ./consumer/scripts/validate-deployment.sh
          ./consumer/scripts/smoke-test.sh

      - name: Deploy if tests pass
        run: docker compose up -d consumer
```

---

## Covers These Tasks

- **T012**: ✅ End-to-end pipeline test
- **T023**: ✅ PostgreSQL insert → OpenSearch verification
- **T024**: ✅ Basic transformation validation (implicit)
- **T036**: ✅ Health endpoint test
- **T043**: ✅ Integration test script
- **T044**: ✅ Final validation (User Stories 1 & 3)

**6 out of 12 deferred tasks validated in 5 minutes**

For comprehensive testing (all 12 tasks), run full suite:
```bash
bash specs/005-consumer-app/scripts/run-all-tests-fast.sh  # 30 min
```

---

## Troubleshooting Common Issues

### "Health endpoint not reachable"
```bash
# Check if consumer is running
docker compose ps consumer

# Check consumer logs
docker compose logs consumer --tail=50

# Restart consumer
docker compose restart consumer
```

### "Test record not found in OpenSearch"
```bash
# Check Debezium connector
bash debezium/scripts/check-connector-status.sh

# Check Kafka topic for events
docker compose exec kafka kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic dbserver.public.videos \
  --from-beginning --max-messages 5

# Increase wait time in smoke-test.sh
# Change: sleep 15 → sleep 30
```

### "Success rate below 99%"
```bash
# Check consumer errors
docker compose logs consumer | grep -i error

# Check metrics for details
curl http://localhost:8080/metrics | jq .processing

# Review dead letter queue
docker compose exec kafka kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic dbserver.public.videos.dlq \
  --from-beginning --max-messages 10
```

---

**Duration**: 5 minutes
**Coverage**: Core functionality (6/12 tasks)
**Use for**: Daily validation, CI/CD, pre-deployment checks
**Created**: 2025-12-28
