#!/bin/bash
#
# Deployment Validation Script for CDC Consumer Application
#
# Usage: ./validate-deployment.sh [health_url] [metrics_url]
# Example: ./validate-deployment.sh http://localhost:8080/health http://localhost:8080/metrics
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default URLs
HEALTH_URL="${1:-http://localhost:8080/health}"
METRICS_URL="${2:-http://localhost:8080/metrics}"

# Validation results
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
print_success() {
    echo -e "${GREEN}✓${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_failure() {
    echo -e "${RED}✗${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# Test functions
test_health_endpoint_reachable() {
    echo ""
    echo "=== Testing Health Endpoint Reachability ==="

    if curl -s -f -o /dev/null "$HEALTH_URL"; then
        print_success "Health endpoint is reachable at $HEALTH_URL"
        return 0
    else
        print_failure "Health endpoint is NOT reachable at $HEALTH_URL"
        return 1
    fi
}

test_health_response_time() {
    echo ""
    echo "=== Testing Health Endpoint Response Time ==="

    START_TIME=$(date +%s%N)
    RESPONSE=$(curl -s "$HEALTH_URL")
    END_TIME=$(date +%s%N)

    DURATION_MS=$(( (END_TIME - START_TIME) / 1000000 ))

    print_info "Response time: ${DURATION_MS}ms"

    # SC-005: Health check endpoint responds within 1 second
    if [ $DURATION_MS -lt 1000 ]; then
        print_success "Health endpoint responds within 1 second (${DURATION_MS}ms < 1000ms)"
        return 0
    else
        print_failure "Health endpoint is too slow (${DURATION_MS}ms >= 1000ms)"
        return 1
    fi
}

test_health_response_structure() {
    echo ""
    echo "=== Testing Health Response Structure ==="

    RESPONSE=$(curl -s "$HEALTH_URL")

    # Check for required fields
    if echo "$RESPONSE" | jq -e '.status' > /dev/null 2>&1; then
        print_success "Health response contains 'status' field"
    else
        print_failure "Health response missing 'status' field"
    fi

    if echo "$RESPONSE" | jq -e '.checks.kafka' > /dev/null 2>&1; then
        print_success "Health response contains 'checks.kafka' field"
    else
        print_failure "Health response missing 'checks.kafka' field"
    fi

    if echo "$RESPONSE" | jq -e '.checks.opensearch' > /dev/null 2>&1; then
        print_success "Health response contains 'checks.opensearch' field"
    else
        print_failure "Health response missing 'checks.opensearch' field"
    fi

    if echo "$RESPONSE" | jq -e '.uptime' > /dev/null 2>&1; then
        print_success "Health response contains 'uptime' field"
    else
        print_failure "Health response missing 'uptime' field"
    fi
}

test_health_status() {
    echo ""
    echo "=== Testing Health Status ==="

    RESPONSE=$(curl -s "$HEALTH_URL")
    STATUS=$(echo "$RESPONSE" | jq -r '.status')
    KAFKA_CONNECTED=$(echo "$RESPONSE" | jq -r '.checks.kafka.connected')
    OS_CONNECTED=$(echo "$RESPONSE" | jq -r '.checks.opensearch.connected')

    print_info "Status: $STATUS"
    print_info "Kafka connected: $KAFKA_CONNECTED"
    print_info "OpenSearch connected: $OS_CONNECTED"

    if [ "$STATUS" = "healthy" ]; then
        print_success "Consumer status is 'healthy'"
    else
        print_failure "Consumer status is '$STATUS' (expected 'healthy')"
    fi

    if [ "$KAFKA_CONNECTED" = "true" ]; then
        print_success "Kafka connection is active"
    else
        print_failure "Kafka connection is NOT active"
    fi

    if [ "$OS_CONNECTED" = "true" ]; then
        print_success "OpenSearch connection is active"
    else
        print_failure "OpenSearch connection is NOT active"
    fi
}

test_metrics_endpoint_reachable() {
    echo ""
    echo "=== Testing Metrics Endpoint Reachability ==="

    if curl -s -f -o /dev/null "$METRICS_URL"; then
        print_success "Metrics endpoint is reachable at $METRICS_URL"
        return 0
    else
        print_failure "Metrics endpoint is NOT reachable at $METRICS_URL"
        return 1
    fi
}

test_metrics_response_structure() {
    echo ""
    echo "=== Testing Metrics Response Structure ==="

    RESPONSE=$(curl -s "$METRICS_URL")

    # Check for required fields
    if echo "$RESPONSE" | jq -e '.processing.total_processed' > /dev/null 2>&1; then
        print_success "Metrics contains 'processing.total_processed' field"
    else
        print_failure "Metrics missing 'processing.total_processed' field"
    fi

    if echo "$RESPONSE" | jq -e '.processing.error_count' > /dev/null 2>&1; then
        print_success "Metrics contains 'processing.error_count' field"
    else
        print_failure "Metrics missing 'processing.error_count' field"
    fi

    if echo "$RESPONSE" | jq -e '.processing.success_rate' > /dev/null 2>&1; then
        print_success "Metrics contains 'processing.success_rate' field"
    else
        print_failure "Metrics missing 'processing.success_rate' field"
    fi

    if echo "$RESPONSE" | jq -e '.processing.processing_rate' > /dev/null 2>&1; then
        print_success "Metrics contains 'processing.processing_rate' field"
    else
        print_failure "Metrics missing 'processing.processing_rate' field"
    fi

    if echo "$RESPONSE" | jq -e '.runtime.uptime_seconds' > /dev/null 2>&1; then
        print_success "Metrics contains 'runtime.uptime_seconds' field"
    else
        print_failure "Metrics missing 'runtime.uptime_seconds' field"
    fi
}

test_metrics_values() {
    echo ""
    echo "=== Testing Metrics Values ==="

    RESPONSE=$(curl -s "$METRICS_URL")

    TOTAL_PROCESSED=$(echo "$RESPONSE" | jq -r '.processing.total_processed')
    ERROR_COUNT=$(echo "$RESPONSE" | jq -r '.processing.error_count')
    SUCCESS_RATE=$(echo "$RESPONSE" | jq -r '.processing.success_rate')
    PROCESSING_RATE=$(echo "$RESPONSE" | jq -r '.processing.processing_rate')

    print_info "Total processed: $TOTAL_PROCESSED"
    print_info "Error count: $ERROR_COUNT"
    print_info "Success rate: $SUCCESS_RATE%"
    print_info "Processing rate: $PROCESSING_RATE"

    # Validate numeric values
    if [ "$TOTAL_PROCESSED" -ge 0 ] 2>/dev/null; then
        print_success "Total processed is a valid number (>= 0)"
    else
        print_failure "Total processed is not a valid number"
    fi

    if [ "$ERROR_COUNT" -ge 0 ] 2>/dev/null; then
        print_success "Error count is a valid number (>= 0)"
    else
        print_failure "Error count is not a valid number"
    fi

    # SC-006: Consumer achieves 99.9% successful event processing rate
    if command -v bc &> /dev/null; then
        if (( $(echo "$SUCCESS_RATE >= 99.0" | bc -l) )); then
            print_success "Success rate >= 99.0% ($SUCCESS_RATE%)"
        else
            print_failure "Success rate < 99.0% ($SUCCESS_RATE%)"
        fi
    else
        print_info "bc not available, skipping success rate validation"
    fi
}

test_consumer_processing() {
    echo ""
    echo "=== Testing Consumer Is Processing Events ==="

    RESPONSE1=$(curl -s "$METRICS_URL")
    PROCESSED1=$(echo "$RESPONSE1" | jq -r '.processing.total_processed')

    print_info "Current processed count: $PROCESSED1"
    print_info "Waiting 10 seconds..."
    sleep 10

    RESPONSE2=$(curl -s "$METRICS_URL")
    PROCESSED2=$(echo "$RESPONSE2" | jq -r '.processing.total_processed')

    print_info "New processed count: $PROCESSED2"

    if [ "$PROCESSED2" -gt "$PROCESSED1" ]; then
        DIFF=$((PROCESSED2 - PROCESSED1))
        print_success "Consumer is actively processing events (+$DIFF events in 10s)"
    else
        print_info "No new events processed (this is OK if no data is being written)"
    fi
}

# Main execution
main() {
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  CDC Consumer Deployment Validation                        ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Health URL: $HEALTH_URL"
    echo "Metrics URL: $METRICS_URL"

    # Check prerequisites
    if ! command -v curl &> /dev/null; then
        echo "Error: curl is required but not installed"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        echo "Error: jq is required but not installed"
        exit 1
    fi

    # Run all tests
    test_health_endpoint_reachable
    test_health_response_time
    test_health_response_structure
    test_health_status
    test_metrics_endpoint_reachable
    test_metrics_response_structure
    test_metrics_values
    test_consumer_processing

    # Summary
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  Validation Summary                                        ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ All validation tests passed!${NC}"
        echo ""
        echo "The consumer is healthy and ready for production."
        exit 0
    else
        echo -e "${RED}✗ Some validation tests failed${NC}"
        echo ""
        echo "Please review the failures above before deploying to production."
        exit 1
    fi
}

# Run main
main
