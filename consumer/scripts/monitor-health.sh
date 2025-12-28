#!/bin/bash
#
# Continuous Health Monitoring Script for CDC Consumer
#
# Usage: ./monitor-health.sh [interval_seconds] [health_url]
# Example: ./monitor-health.sh 5 http://localhost:8080/health
#

# Configuration
INTERVAL="${1:-5}"
HEALTH_URL="${2:-http://localhost:8080/health}"
METRICS_URL="${HEALTH_URL/health/metrics}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counter for consecutive failures
CONSECUTIVE_FAILURES=0
MAX_FAILURES_BEFORE_ALERT=3

clear
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  CDC Consumer Health Monitor                               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Monitoring: $HEALTH_URL"
echo "Interval: ${INTERVAL}s"
echo "Press Ctrl+C to stop"
echo ""

# Function to display health status
display_health() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Fetch health data
    local health_response=$(curl -s "$HEALTH_URL" 2>/dev/null)
    local metrics_response=$(curl -s "$METRICS_URL" 2>/dev/null)

    # Check if endpoints are reachable
    if [ -z "$health_response" ]; then
        echo -e "${RED}[$timestamp] ✗ Health endpoint unreachable${NC}"
        CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))

        if [ $CONSECUTIVE_FAILURES -ge $MAX_FAILURES_BEFORE_ALERT ]; then
            echo -e "${RED}⚠️  ALERT: Consumer has been unreachable for $((CONSECUTIVE_FAILURES * INTERVAL)) seconds!${NC}"
        fi
        return
    fi

    # Parse health response
    local status=$(echo "$health_response" | jq -r '.status // "unknown"')
    local kafka_connected=$(echo "$health_response" | jq -r '.checks.kafka.connected // false')
    local os_connected=$(echo "$health_response" | jq -r '.checks.opensearch.connected // false')
    local uptime=$(echo "$health_response" | jq -r '.uptime // "unknown"')

    # Parse metrics response
    local total_processed=$(echo "$metrics_response" | jq -r '.processing.total_processed // 0')
    local error_count=$(echo "$metrics_response" | jq -r '.processing.error_count // 0')
    local success_rate=$(echo "$metrics_response" | jq -r '.processing.success_rate // 0')
    local processing_rate=$(echo "$metrics_response" | jq -r '.processing.processing_rate // "0 events/sec"')

    # Determine status color
    local status_color=$GREEN
    if [ "$status" != "healthy" ]; then
        status_color=$RED
        CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
    else
        CONSECUTIVE_FAILURES=0
    fi

    # Connection status colors
    local kafka_color=$GREEN
    [ "$kafka_connected" != "true" ] && kafka_color=$RED

    local os_color=$GREEN
    [ "$os_connected" != "true" ] && os_color=$RED

    # Display status line
    echo -e "${BLUE}[$timestamp]${NC} Status: ${status_color}${status}${NC} | " \
         "Kafka: ${kafka_color}${kafka_connected}${NC} | " \
         "OpenSearch: ${os_color}${os_connected}${NC} | " \
         "Uptime: ${uptime}"

    # Display metrics
    echo -e "  ${YELLOW}→${NC} Processed: ${total_processed} | " \
         "Errors: ${error_count} | " \
         "Success: ${success_rate}% | " \
         "Rate: ${processing_rate}"

    # Alert if degraded
    if [ "$status" != "healthy" ]; then
        if [ $CONSECUTIVE_FAILURES -ge $MAX_FAILURES_BEFORE_ALERT ]; then
            echo -e "  ${RED}⚠️  ALERT: Consumer has been degraded for $((CONSECUTIVE_FAILURES * INTERVAL)) seconds!${NC}"
        fi
    fi

    # Alert on low success rate
    if command -v bc &> /dev/null; then
        if (( $(echo "$success_rate < 99.0" | bc -l) )) && [ "$total_processed" -gt 0 ]; then
            echo -e "  ${YELLOW}⚠️  WARNING: Success rate below 99% (${success_rate}%)${NC}"
        fi
    fi
}

# Main monitoring loop
trap 'echo ""; echo "Monitoring stopped."; exit 0' INT

while true; do
    display_health
    sleep "$INTERVAL"
done
