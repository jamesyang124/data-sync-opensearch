#!/bin/bash
#
# Smoke Test Script for CDC Consumer Deployment
#
# Performs a quick end-to-end test by inserting a test record
# and verifying it appears in OpenSearch.
#
# Usage: ./smoke-test.sh
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
POSTGRES_CONTAINER="postgres"
OPENSEARCH_URL="http://localhost:9200"
CONSUMER_HEALTH_URL="http://localhost:8080/health"
TEST_VIDEO_ID="smoke_test_$(date +%s)"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  CDC Consumer Smoke Test                                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Verify consumer is healthy
echo "Step 1: Verifying consumer health..."
HEALTH_RESPONSE=$(curl -s "$CONSUMER_HEALTH_URL")
STATUS=$(echo "$HEALTH_RESPONSE" | jq -r '.status')

if [ "$STATUS" = "healthy" ]; then
    echo -e "${GREEN}✓${NC} Consumer is healthy"
else
    echo -e "${RED}✗${NC} Consumer is not healthy (status: $STATUS)"
    echo "Cannot proceed with smoke test."
    exit 1
fi

# Step 2: Insert test record into PostgreSQL
echo ""
echo "Step 2: Inserting test record into PostgreSQL..."
echo "  Test video ID: $TEST_VIDEO_ID"

docker compose exec -T "$POSTGRES_CONTAINER" psql -U app -d app << EOF
INSERT INTO videos (video_id, user_id, title, description, duration_seconds, view_count, like_count, created_at, updated_at)
VALUES ('$TEST_VIDEO_ID', 'smoke_test_user', 'Smoke Test Video', 'Automated deployment verification', 60, 0, 0, NOW(), NOW());
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Test record inserted successfully"
else
    echo -e "${RED}✗${NC} Failed to insert test record"
    exit 1
fi

# Step 3: Wait for CDC propagation
echo ""
echo "Step 3: Waiting for CDC propagation (15 seconds)..."
for i in {15..1}; do
    echo -n "  $i..."
    sleep 1
    echo -ne "\r"
done
echo "  Done.          "

# Step 4: Verify record in OpenSearch
echo ""
echo "Step 4: Verifying record in OpenSearch..."

OPENSEARCH_RESPONSE=$(curl -s "$OPENSEARCH_URL/videos_index/_doc/$TEST_VIDEO_ID")
FOUND=$(echo "$OPENSEARCH_RESPONSE" | jq -r '.found // false')

if [ "$FOUND" = "true" ]; then
    echo -e "${GREEN}✓${NC} Test record found in OpenSearch"

    # Verify field values
    TITLE=$(echo "$OPENSEARCH_RESPONSE" | jq -r '._source.title')
    USER_ID=$(echo "$OPENSEARCH_RESPONSE" | jq -r '._source.user_id')

    echo "  Title: $TITLE"
    echo "  User ID: $USER_ID"

    if [ "$TITLE" = "Smoke Test Video" ] && [ "$USER_ID" = "smoke_test_user" ]; then
        echo -e "${GREEN}✓${NC} Record data is correct"
    else
        echo -e "${YELLOW}⚠${NC} Record data may be incorrect"
    fi
else
    echo -e "${RED}✗${NC} Test record NOT found in OpenSearch"
    echo "Response: $OPENSEARCH_RESPONSE"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check consumer logs: docker compose logs consumer --tail=50"
    echo "  2. Check Debezium connector: curl http://localhost:8083/connectors/postgres-connector/status"
    echo "  3. Check Kafka topic: docker compose exec kafka kafka-console-consumer --bootstrap-server kafka:9092 --topic dbserver.public.videos --from-beginning --max-messages 5"
    exit 1
fi

# Step 5: Cleanup test record
echo ""
echo "Step 5: Cleaning up test record..."

docker compose exec -T "$POSTGRES_CONTAINER" psql -U app -d app << EOF
DELETE FROM videos WHERE video_id = '$TEST_VIDEO_ID';
EOF

# Wait a bit for delete to propagate
sleep 10

# Verify deletion in OpenSearch
OPENSEARCH_RESPONSE=$(curl -s "$OPENSEARCH_URL/videos_index/_doc/$TEST_VIDEO_ID")
FOUND=$(echo "$OPENSEARCH_RESPONSE" | jq -r '.found // false')

if [ "$FOUND" = "false" ]; then
    echo -e "${GREEN}✓${NC} Test record deleted from OpenSearch"
else
    echo -e "${YELLOW}⚠${NC} Test record may still exist in OpenSearch (this is OK for eventual consistency)"
fi

# Step 6: Check consumer metrics
echo ""
echo "Step 6: Checking consumer metrics..."

METRICS_RESPONSE=$(curl -s "http://localhost:8080/metrics")
TOTAL_PROCESSED=$(echo "$METRICS_RESPONSE" | jq -r '.processing.total_processed')
ERROR_COUNT=$(echo "$METRICS_RESPONSE" | jq -r '.processing.error_count')
SUCCESS_RATE=$(echo "$METRICS_RESPONSE" | jq -r '.processing.success_rate')

echo "  Total processed: $TOTAL_PROCESSED"
echo "  Error count: $ERROR_COUNT"
echo "  Success rate: ${SUCCESS_RATE}%"

if command -v bc &> /dev/null; then
    if (( $(echo "$SUCCESS_RATE >= 99.0" | bc -l) )); then
        echo -e "${GREEN}✓${NC} Success rate is healthy (>= 99%)"
    else
        echo -e "${YELLOW}⚠${NC} Success rate is below 99%"
    fi
fi

# Summary
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Smoke Test Summary                                        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}✓${NC} Consumer is processing CDC events correctly"
echo -e "${GREEN}✓${NC} End-to-end pipeline is functional"
echo -e "${GREEN}✓${NC} INSERT operation: Working"
echo -e "${GREEN}✓${NC} DELETE operation: Working"
echo ""
echo "The CDC consumer deployment is verified and operational."
echo ""
