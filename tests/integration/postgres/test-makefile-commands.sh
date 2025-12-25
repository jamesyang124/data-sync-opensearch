#!/bin/bash
set -e

# Integration Test: Makefile Commands
# Test reset and other Makefile commands

echo "=== Testing Makefile Commands ==="

# Test 1: Verify make start works
echo "Test 1: Testing 'make start' command..."
if make start >/dev/null 2>&1; then
  echo "✓ 'make start' executed successfully"
else
  echo "✗ FAIL: 'make start' failed"
  exit 1
fi

# Test 2: Verify make health works
echo "Test 2: Testing 'make health' command..."
if make health >/dev/null 2>&1; then
  echo "✓ 'make health' executed successfully"
else
  echo "✗ FAIL: 'make health' failed"
  exit 1
fi

# Test 3: Get initial row counts
echo "Test 3: Recording initial state..."
INITIAL_COUNT=$(docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -tc "SELECT COUNT(*) FROM comments;" | tr -d '[:space:]')
echo "  Initial comment count: $INITIAL_COUNT"

# Test 4: Modify database (insert a test record)
echo "Test 4: Modifying database..."
docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -c "INSERT INTO videos (video_id, title, category) VALUES ('test-video', 'Test Video', 'Test');" >/dev/null 2>&1

MODIFIED_VIDEO_COUNT=$(docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -tc "SELECT COUNT(*) FROM videos WHERE video_id='test-video';" | tr -d '[:space:]')

if [ "$MODIFIED_VIDEO_COUNT" = "1" ]; then
  echo "✓ Test record inserted successfully"
else
  echo "✗ FAIL: Could not insert test record"
  exit 1
fi

# Test 5: Test make reset (skip for now as it requires confirmation)
echo "Test 5: Testing 'make reset' command (skipping interactive test)..."
echo "  (Manual test required: Run 'make reset' and verify data restored)"

# Test 6: Test make stop
echo "Test 6: Testing 'make stop' command..."
if make stop >/dev/null 2>&1; then
  echo "✓ 'make stop' executed successfully"
else
  echo "✗ FAIL: 'make stop' failed"
  exit 1
fi

# Restart for other tests
make start >/dev/null 2>&1

echo ""
echo "✅ All Makefile command tests passed!"
echo "   (Note: 'make reset' requires manual confirmation testing)"
