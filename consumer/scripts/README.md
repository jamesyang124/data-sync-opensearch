# Consumer Deployment and Validation Scripts

This directory contains scripts for validating, monitoring, and testing the CDC Consumer application deployment.

## Scripts Overview

### 1. validate-deployment.sh

**Purpose**: Comprehensive deployment validation testing health and metrics endpoints.

**Usage**:
```bash
./validate-deployment.sh [health_url] [metrics_url]

# Examples:
./validate-deployment.sh
./validate-deployment.sh http://localhost:8080/health http://localhost:8080/metrics
./validate-deployment.sh http://consumer:8080/health http://consumer:8080/metrics
```

**What it tests**:
- ✅ Health endpoint reachability
- ✅ Health endpoint response time (<1 second per SC-005)
- ✅ Health response structure (status, checks, uptime)
- ✅ Kafka and OpenSearch connectivity status
- ✅ Metrics endpoint reachability
- ✅ Metrics response structure (processing stats, runtime info)
- ✅ Metrics value validation (success rate >= 99% per SC-006)
- ✅ Consumer is actively processing events

**Exit codes**:
- `0`: All tests passed
- `1`: One or more tests failed

**Prerequisites**:
- `curl` command available
- `jq` command available
- Consumer service running

**Example output**:
```
╔════════════════════════════════════════════════════════════╗
║  CDC Consumer Deployment Validation                        ║
╚════════════════════════════════════════════════════════════╝

=== Testing Health Endpoint Reachability ===
✓ Health endpoint is reachable at http://localhost:8080/health

=== Testing Health Endpoint Response Time ===
ℹ Response time: 127ms
✓ Health endpoint responds within 1 second (127ms < 1000ms)

...

╔════════════════════════════════════════════════════════════╗
║  Validation Summary                                        ║
╚════════════════════════════════════════════════════════════╝

Tests passed: 18
Tests failed: 0

✓ All validation tests passed!

The consumer is healthy and ready for production.
```

---

### 2. monitor-health.sh

**Purpose**: Continuous real-time monitoring of consumer health and performance metrics.

**Usage**:
```bash
./monitor-health.sh [interval_seconds] [health_url]

# Examples:
./monitor-health.sh              # Monitor every 5 seconds (default)
./monitor-health.sh 10           # Monitor every 10 seconds
./monitor-health.sh 3 http://consumer:8080/health
```

**What it monitors**:
- Consumer status (healthy/degraded)
- Kafka connectivity
- OpenSearch connectivity
- Uptime
- Total events processed
- Error count
- Success rate (%)
- Processing rate (events/sec)

**Features**:
- 🔴 Red alerts for degraded status or connection failures
- 🟡 Yellow warnings for success rate <99%
- 🟢 Green indicators for healthy state
- ⚠️ Consecutive failure alerts (after 3 failures)
- Real-time metrics updates

**Controls**:
- `Ctrl+C`: Stop monitoring

**Example output**:
```
╔════════════════════════════════════════════════════════════╗
║  CDC Consumer Health Monitor                               ║
╚════════════════════════════════════════════════════════════╝

Monitoring: http://localhost:8080/health
Interval: 5s
Press Ctrl+C to stop

[2025-12-28 08:15:32] Status: healthy | Kafka: true | OpenSearch: true | Uptime: 2h15m30s
  → Processed: 15230 | Errors: 12 | Success: 99.92% | Rate: 125.50 events/sec

[2025-12-28 08:15:37] Status: healthy | Kafka: true | OpenSearch: true | Uptime: 2h15m35s
  → Processed: 15855 | Errors: 12 | Success: 99.92% | Rate: 125.00 events/sec
```

**Use cases**:
- Production monitoring dashboards
- Post-deployment health verification
- Troubleshooting performance issues
- Long-running system validation

---

### 3. smoke-test.sh

**Purpose**: Quick end-to-end smoke test verifying the complete CDC pipeline.

**Usage**:
```bash
./smoke-test.sh
```

**What it does**:
1. Verifies consumer health status
2. Inserts a test record into PostgreSQL
3. Waits for CDC propagation (15 seconds)
4. Verifies record appears in OpenSearch with correct data
5. Deletes test record from PostgreSQL
6. Verifies record is deleted from OpenSearch
7. Checks consumer metrics

**Exit codes**:
- `0`: Smoke test passed (pipeline is functional)
- `1`: Smoke test failed (pipeline has issues)

**Prerequisites**:
- PostgreSQL container running (`postgres`)
- OpenSearch accessible at `http://localhost:9200`
- Consumer accessible at `http://localhost:8080`
- `docker compose` command available
- `jq` command available

**Example output**:
```
╔════════════════════════════════════════════════════════════╗
║  CDC Consumer Smoke Test                                   ║
╚════════════════════════════════════════════════════════════╝

Step 1: Verifying consumer health...
✓ Consumer is healthy

Step 2: Inserting test record into PostgreSQL...
  Test video ID: smoke_test_1703845123
✓ Test record inserted successfully

Step 3: Waiting for CDC propagation (15 seconds)...
  Done.

Step 4: Verifying record in OpenSearch...
✓ Test record found in OpenSearch
  Title: Smoke Test Video
  User ID: smoke_test_user
✓ Record data is correct

Step 5: Cleaning up test record...
✓ Test record deleted from OpenSearch

Step 6: Checking consumer metrics...
  Total processed: 15230
  Error count: 12
  Success rate: 99.92%
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

**Troubleshooting**:
If smoke test fails, it provides specific troubleshooting commands:
- Check consumer logs
- Check Debezium connector status
- Check Kafka topic messages

**Use cases**:
- Post-deployment verification
- CI/CD pipeline validation
- Quick health check before production release
- Regression testing after changes

---

## Common Workflows

### Initial Deployment Validation

```bash
# 1. Validate deployment
./validate-deployment.sh

# 2. Run smoke test
./smoke-test.sh

# 3. Start continuous monitoring
./monitor-health.sh
```

### Production Monitoring

```bash
# Terminal 1: Monitor health continuously
./monitor-health.sh 10

# Terminal 2: Watch consumer logs
docker compose logs consumer --follow --tail=100

# Terminal 3: Check metrics on demand
watch -n 5 'curl -s http://localhost:8080/metrics | jq .'
```

### Troubleshooting

```bash
# Quick health check
curl http://localhost:8080/health | jq .

# Detailed validation
./validate-deployment.sh

# End-to-end verification
./smoke-test.sh

# Check if consumer is processing
./monitor-health.sh 5
# Look for increasing "Processed" count
```

### CI/CD Integration

```bash
#!/bin/bash
# deploy-and-validate.sh

# Deploy consumer
docker compose --profile app up -d consumer

# Wait for startup
sleep 10

# Validate deployment
./consumer/scripts/validate-deployment.sh || exit 1

# Run smoke test
./consumer/scripts/smoke-test.sh || exit 1

echo "Deployment validated successfully!"
```

---

## Script Dependencies

All scripts require:
- **curl**: HTTP client for endpoint testing
- **jq**: JSON processor for parsing responses

Optional:
- **bc**: Calculator for floating-point comparisons (success rate validation)

### Installing dependencies

**macOS**:
```bash
brew install curl jq bc
```

**Ubuntu/Debian**:
```bash
sudo apt-get install curl jq bc
```

**RHEL/CentOS**:
```bash
sudo yum install curl jq bc
```

---

## Success Criteria Mapping

These scripts validate the following success criteria from spec.md:

- **SC-001**: End-to-end latency <10s → `smoke-test.sh` (15s propagation includes buffer)
- **SC-002**: 100 events/sec throughput → `monitor-health.sh` (processing_rate metric)
- **SC-005**: <1s health check response → `validate-deployment.sh` (response time test)
- **SC-006**: 99.9% success rate → `validate-deployment.sh` + `monitor-health.sh` (success_rate metric)

---

## Script Maintenance

**Location**: `consumer/scripts/`

**Permissions**: All scripts should be executable
```bash
chmod +x consumer/scripts/*.sh
```

**Testing**: Test scripts in development environment before production use
```bash
# Test against local deployment
export HEALTH_URL=http://localhost:8080/health
./validate-deployment.sh
./smoke-test.sh
```

**Customization**: Scripts use environment-based URLs and can be customized for different deployment targets.

---

## Support

For issues with these scripts:
1. Check script prerequisites are installed
2. Verify consumer is running: `docker compose ps consumer`
3. Check consumer logs: `docker compose logs consumer --tail=50`
4. Review script source code for detailed error messages

For consumer application issues, see:
- [Consumer README](../README.md)
- [Specification](../../specs/005-consumer-app/spec.md)
- [Test Execution Checklist](../../specs/005-consumer-app/checklists/test-execution.md)
