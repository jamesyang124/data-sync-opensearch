# Implementation Plan: Kafka Performance Validation and Delivery Guarantee Testing

**Branch**: `003-kafka-validation` | **Date**: 2025-12-25 | **Spec**: [spec.md](spec.md)

## Summary

Validate and test the Kafka infrastructure deployed in Feature 002 (Debezium CDC Setup) through performance benchmarking and delivery guarantee testing. Execute load tests simulating CDC workloads (1000 msg/sec throughput, 895K snapshot), test at-least-once delivery under failure scenarios, and generate performance/reliability reports with tuning recommendations.

**Technical Approach**: Use Kafka built-in performance tools (`kafka-producer-perf-test`, `kafka-consumer-perf-test`), custom bash scripts for CDC workload simulation, Docker stats for resource monitoring, and automated integration tests for delivery guarantee validation. Generate markdown reports with metrics and recommendations.

## Technical Context

**Language/Version**: Bash for test scripts, JSON for metrics output, Markdown for reports
**Primary Dependencies**: Kafka Confluent Platform 7.6.0 (from Feature 002), Docker CLI for stats, jq for JSON processing
**Storage**: Test results and reports stored in `kafka/tests/results/`
**Testing**: Integration tests for performance benchmarks and delivery guarantee validation
**Target Platform**: Docker Desktop for local development (same as Feature 002)
**Project Type**: Testing and validation (non-functional requirements)
**Performance Goals**: Validate ≥1000 msg/sec throughput, <100ms p95 latency, <10s startup, 0% message loss under failures
**Constraints**: Single Kafka broker (from Feature 002), development environment only
**Scale/Scope**: 5 performance benchmarks, 5 delivery guarantee tests, 2 automated test suites, 2 markdown reports

## Prerequisites

**CRITICAL**: This feature requires Feature 002 (Debezium CDC Setup) to be complete and operational:

- ✅ Kafka broker (Confluent Platform 7.6.0) running in docker-compose.yml
- ✅ CDC topics created: dbserver.public.{videos,users,comments}
- ✅ Kafka UI accessible on port 8081
- ✅ Debezium connector producing CDC events
- ✅ At-least-once delivery configuration active
- ✅ Envelope format configured (no unwrap SMT)

**Validation Command**:
```bash
# Verify Feature 002 prerequisites
make status-cdc  # Should show connector RUNNING
docker compose ps kafka  # Should show kafka service up
curl -s http://localhost:8081  # Should return Kafka UI
```

## Constitution Check

✅ **ALL GATES PASSED**

- Plugin Architecture: Tests are standalone and reusable - PASS
- Event-Driven Integration: Validates Kafka as message backbone (**Debezium** → Kafka → **Consumer**) - PASS
- Integration Testing: Core focus of this feature - PASS
- Observability: Performance metrics and reports provide visibility - PASS
- Docker-First: All tests run against Docker Compose services - PASS

## Project Structure

### Documentation (this feature)

```text
specs/003-kafka-validation/
├── spec.md              # This feature specification (rewritten)
├── plan.md              # This file (rewritten)
├── tasks.md             # Task breakdown (to be rewritten)
└── reports/             # Generated performance and delivery reports (new)
    ├── performance-baseline.md
    └── delivery-guarantees.md
```

### Source Code (repository root)

```text
kafka/                              # Existing from Feature 002
├── tests/                          # Enhance existing test directory
│   ├── performance/                # NEW: Performance benchmarks
│   │   ├── run-throughput-test.sh
│   │   ├── run-burst-test.sh
│   │   ├── run-sustained-load-test.sh
│   │   ├── run-snapshot-simulation.sh
│   │   ├── run-startup-test.sh
│   │   └── collect-metrics.sh
│   ├── delivery/                   # NEW: Delivery guarantee tests
│   │   ├── test-broker-restart.sh
│   │   ├── test-consumer-restart.sh
│   │   ├── test-network-partition.sh
│   │   ├── test-debezium-offset-recovery.sh
│   │   └── test-multiple-consumers.sh
│   ├── results/                    # NEW: Test results and metrics
│   │   ├── .gitignore              # Ignore raw metrics files
│   │   └── README.md               # How to interpret results
│   ├── test-all-performance.sh     # NEW: Run all performance tests
│   ├── test-all-delivery.sh        # NEW: Run all delivery tests
│   └── generate-reports.sh         # NEW: Generate markdown reports
├── scripts/                        # Existing from Feature 002
│   └── (unchanged)
└── README.md                       # Update with performance validation section

Makefile                            # Add test targets
specs/003-kafka-validation/reports/      # Generated reports (committed to git)
```

**Structure Decision**: Enhance existing `kafka/tests/` directory from Feature 002 with new subdirectories for performance and delivery tests. Keep tests co-located with the Kafka infrastructure they validate. Generate reports in `specs/003-kafka-validation/reports/` for documentation purposes.

## Complexity Tracking

**No constitutional violations** - No entries required.

All constitutional principles satisfied without exceptions. This feature focuses on validation and testing, which aligns with the project's Integration Testing (NON-NEGOTIABLE) principle.

## Technical Design

### Performance Benchmark Implementation

**Test Harness**: Use Kafka's built-in `kafka-producer-perf-test` and `kafka-consumer-perf-test` tools with CDC-like message payloads.

**Sample Command**:
```bash
docker compose exec kafka kafka-producer-perf-test \
  --topic dbserver.public.comments \
  --num-records 60000 \
  --throughput 1000 \
  --record-size 5120 \
  --producer-props bootstrap.servers=localhost:9092 \
                     acks=all \
                     retries=2147483647 \
  --print-metrics
```

**Metrics Collection**: Parse output JSON, capture Docker stats every second, store in `kafka/tests/results/`.

### Delivery Guarantee Test Implementation

**Test Pattern**: Produce messages → Inject failure → Resume → Verify count

**Sample Test**:
```bash
#!/bin/bash
# test-broker-restart.sh

# Produce 1000 messages
kafka-console-producer --topic test-delivery --broker-list kafka:9092 < messages.txt &
PRODUCER_PID=$!

# Wait for 500 messages
sleep 5

# Restart broker
docker compose restart kafka

# Wait for recovery
sleep 10

# Consume all messages
COUNT=$(kafka-console-consumer --topic test-delivery --from-beginning --max-messages 1000 --timeout-ms 30000 | wc -l)

# Verify no loss (may have duplicates)
if [ "$COUNT" -ge 1000 ]; then
  echo "✅ PASS: Received $COUNT messages (expected ≥1000)"
else
  echo "❌ FAIL: Received $COUNT messages (expected ≥1000)"
  exit 1
fi
```

### Report Generation

**Performance Report Structure**:
```markdown
# Kafka Performance Baseline

## Test Environment
- Kafka: Confluent Platform 7.6.0
- Topics: dbserver.public.{videos,users,comments}
- Configuration: at-least-once delivery

## Benchmark Results

### Throughput Test (1000 msg/sec for 60s)
- Messages Sent: 60,000
- Actual Throughput: 1,050 msg/sec
- Latency (p50): 12ms
- Latency (p95): 45ms
- Latency (p99): 78ms
- **Result**: ✅ PASS (exceeds 1000 msg/sec requirement)

### Resource Usage
- CPU: 45% (peak 68%)
- Memory: 1.2GB (peak 1.5GB)
- Disk I/O: 15 MB/s write
- **Result**: ✅ PASS (under 2GB memory limit)

## Recommendations
- Current configuration meets requirements
- Consider increasing `num.io.threads` if CPU usage >80%
- Monitor disk usage growth rate for retention tuning
```

## Phase Breakdown

### Phase 1: Setup (Prerequisites)
1. Verify Feature 002 is complete
2. Create test directory structure
3. Install test dependencies (jq, bc for calculations)

### Phase 2: Performance Benchmarks
1. Implement throughput test (1000 msg/sec)
2. Implement burst test (5000 msg/sec)
3. Implement sustained load test (500 msg/sec, 5 min)
4. Implement snapshot simulation (895K messages)
5. Implement startup test
6. Create metrics collection script
7. Create automated test runner

### Phase 3: Delivery Guarantee Tests
1. Implement broker restart test
2. Implement consumer restart test
3. Implement network partition test
4. Implement Debezium offset recovery test
5. Implement multiple consumer groups test
6. Create automated test runner

### Phase 4: Reporting & Documentation
1. Generate performance baseline report
2. Generate delivery guarantee report
3. Update kafka/README.md with test instructions
4. Document tuning recommendations
5. Add Makefile targets for test execution

## Integration Testing Strategy

**Test Automation**: All tests runnable via Makefile targets

```bash
# Run all performance tests
make test-kafka-performance

# Run all delivery guarantee tests
make test-kafka-delivery

# Generate reports
make kafka-reports
```

**Test Validation**: Each test script exits with code 0 (pass) or 1 (fail), enabling CI/CD integration.

**Test Repeatability**: Tests can be re-run after configuration changes or Kafka upgrades to validate changes.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Docker resource constraints affect test results | HIGH | Document minimum host requirements (4GB RAM, 20GB disk), validate before tests |
| Broker restart tests disrupt other services | MEDIUM | Use separate test topics, coordinate with PostgreSQL/Debezium state |
| Performance variability due to host load | MEDIUM | Run tests 3 times, report median/average, document variance |
| Test timeout issues on slow machines | LOW | Increase timeout values, make configurable via env vars |

## Success Metrics

- ✅ All 5 performance benchmarks complete successfully
- ✅ All 5 delivery guarantee tests complete successfully
- ✅ Performance report generated with all required metrics
- ✅ Delivery guarantee report documents 0% message loss
- ✅ Makefile targets work end-to-end
- ✅ Tests are repeatable and deterministic

## Next Steps After This Feature

1. **Feature 004: Consumer Application** - Build Golang consumer that reads from Kafka topics validated by this feature
2. **Feature 005: OpenSearch Integration** - Sync consumer output to OpenSearch
3. **Production Tuning** - Apply recommendations from performance reports for production deployment
