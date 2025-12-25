# Kafka Test Results

This directory contains test outputs from performance benchmarks and delivery guarantee tests (Feature 003: Kafka Validation).

## Directory Purpose

All test scripts write their results to this directory:
- Raw metrics logs (`.log` files)
- JSON metrics for programmatic analysis (`.json` files)
- Docker container stats snapshots

**Note**: This directory is gitignored. Test results are ephemeral and should be regenerated on each environment.

## File Naming Convention

Test results use timestamp-based naming for uniqueness:

```
<test-name>-<output-type>-<timestamp>.log
<test-name>-metrics-<timestamp>.json
```

**Examples:**
- `throughput-producer-1703498340.log` - Producer performance test output
- `throughput-consumer-1703498340.log` - Consumer performance test output
- `throughput-metrics-1703498340.json` - JSON metrics for throughput test
- `sustained-docker-stats-1703498340.log` - Docker container resource usage
- `performance-summary-1703498340.log` - Performance test suite summary
- `delivery-summary-1703498340.log` - Delivery test suite summary

## Test Output Files

### Performance Benchmarks

| File Pattern | Description |
|--------------|-------------|
| `throughput-producer-*.log` | kafka-producer-perf-test output (1000 msg/sec for 60s) |
| `throughput-consumer-*.log` | kafka-consumer-perf-test output |
| `burst-producer-*.log` | Burst test output (5000 msg/sec for 10s) |
| `sustained-producer-*.log` | Sustained load test output (500 msg/sec for 5 minutes) |
| `sustained-docker-stats-*.log` | Docker container resource usage during sustained load |
| `snapshot-producer-*.log` | Snapshot simulation output (895K records) |
| `startup-test-*.log` | Broker startup time measurements |
| `*-metrics-*.json` | JSON-formatted metrics for programmatic analysis |
| `performance-summary-*.log` | Test suite summary (PASS/FAIL status for all 5 tests) |

### Delivery Guarantee Tests

| File Pattern | Description |
|--------------|-------------|
| `broker-restart-producer-*.log` | Producer output during broker restart test |
| `broker-restart-consumer-*.log` | Consumer output after broker restart |
| `consumer-restart-consumer1-*.log` | First consumer batch (before restart) |
| `consumer-restart-consumer2-*.log` | Second consumer batch (after restart) |
| `network-partition-producer-*.log` | Producer output during network partition |
| `network-partition-consumer-*.log` | Consumer output after partition recovery |
| `delivery-summary-*.log` | Test suite summary (PASS/FAIL status for all 5 tests) |

## Metrics Interpretation

### Performance Metrics (from JSON files)

```json
{
  "test_name": "throughput",
  "producer": {
    "throughput_msg_per_sec": "1234.56",
    "latency": {
      "avg_ms": "45.32",
      "p95_ms": "78.45",
      "p99_ms": "125.67"
    }
  }
}
```

**Key Metrics:**
- **Throughput**: Messages per second (target: ≥1000 for throughput test)
- **Latency (avg)**: Average end-to-end latency in milliseconds
- **Latency (p95)**: 95th percentile latency (target: <100ms for throughput test)
- **Latency (p99)**: 99th percentile latency

### Delivery Test Metrics

**Success Criteria**: All delivery tests should show **0% message loss**

- **Messages Sent**: Total messages produced by test
- **Messages Received**: Total messages consumed by test
- **Message Loss**: Sent - Received (should be 0 for at-least-once delivery)
- **Possible Duplicates**: Received - Sent (acceptable for at-least-once delivery)

**Example (PASS)**:
```
Messages Sent: 1000
Messages Received: 1000
Message Loss: 0 (0%)
```

**Example (ACCEPTABLE with duplicates)**:
```
Messages Sent: 1000
Messages Received: 1003
Message Loss: 0 (0%)
Duplicates: 3 (acceptable for at-least-once delivery)
```

## Viewing Results

### Quick Summary

```bash
# View latest performance test summary
ls -t kafka/tests/results/performance-summary-*.log | head -n 1 | xargs cat

# View latest delivery test summary
ls -t kafka/tests/results/delivery-summary-*.log | head -n 1 | xargs cat
```

### Detailed Metrics

```bash
# View throughput test metrics
ls -t kafka/tests/results/throughput-producer-*.log | head -n 1 | xargs cat

# View JSON metrics for programmatic analysis
ls -t kafka/tests/results/*-metrics-*.json | head -n 1 | xargs jq
```

### Docker Stats

```bash
# View resource usage during sustained load test
ls -t kafka/tests/results/sustained-docker-stats-*.log | head -n 1 | xargs cat
```

## Generating Reports

Test results are parsed and summarized into markdown reports:

```bash
# Generate reports from test results
bash kafka/tests/generate-reports.sh

# Or use Makefile target
make kafka-reports
```

**Output Reports:**
- `specs/003-kafka-validation/reports/performance-baseline.md`
- `specs/003-kafka-validation/reports/delivery-guarantees.md`

## Cleanup

To remove all test results (useful before regenerating fresh metrics):

```bash
# Remove all test results except .gitignore
find kafka/tests/results/ -type f ! -name '.gitignore' -delete
```

## Troubleshooting

### No Test Results

**Cause**: Tests haven't been run yet

**Solution**:
```bash
make test-kafka-performance  # Generate performance results
make test-kafka-delivery     # Generate delivery results
```

### Incomplete Metrics

**Cause**: Test may have failed mid-execution

**Check**:
1. Look for error messages in the log files
2. Verify Feature 002 (CDC Setup) is running: `make status-cdc`
3. Re-run the specific test: `bash kafka/tests/performance/run-throughput-test.sh`

### JSON Parsing Errors

**Cause**: Metrics collection script couldn't parse kafka-perf-test output

**Debug**:
```bash
# Check raw producer output for errors
cat kafka/tests/results/throughput-producer-*.log | grep -i error
```

## Related Documentation

- [Feature 003: Kafka Validation Spec](../../specs/003-kafka-validation/spec.md)
- [Performance Baseline Report](../../specs/003-kafka-validation/reports/performance-baseline.md)
- [Delivery Guarantees Report](../../specs/003-kafka-validation/reports/delivery-guarantees.md)
- [Kafka README](../README.md)
