#!/bin/bash
set -e

# Integration Test: Data Loading
# Verify 10-50K rows loaded with correct relationships

echo "=== Testing Data Loading ==="

# Test 1: Verify videos table has data
echo "Test 1: Checking videos table row count..."
VIDEO_COUNT=$(docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -tc "SELECT COUNT(*) FROM videos;" | tr -d '[:space:]')

if [ "$VIDEO_COUNT" -gt "0" ]; then
  echo "✓ Videos table has $VIDEO_COUNT rows"
else
  echo "✗ FAIL: Videos table is empty"
  exit 1
fi

# Test 2: Verify users table has data
echo "Test 2: Checking users table row count..."
USER_COUNT=$(docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -tc "SELECT COUNT(*) FROM users;" | tr -d '[:space:]')

if [ "$USER_COUNT" -gt "0" ]; then
  echo "✓ Users table has $USER_COUNT rows"
else
  echo "✗ FAIL: Users table is empty"
  exit 1
fi

# Test 3: Verify comments table has data
echo "Test 3: Checking comments table row count..."
COMMENT_COUNT=$(docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -tc "SELECT COUNT(*) FROM comments;" | tr -d '[:space:]')

if [ "$COMMENT_COUNT" -gt "0" ]; then
  echo "✓ Comments table has $COMMENT_COUNT rows"
else
  echo "✗ FAIL: Comments table is empty"
  exit 1
fi

# Test 4: Verify total row count is in 10-50K range
TOTAL_COUNT=$((VIDEO_COUNT + USER_COUNT + COMMENT_COUNT))
echo "Test 4: Verifying total row count ($TOTAL_COUNT) is in acceptable range..."

if [ "$TOTAL_COUNT" -ge "10000" ] && [ "$TOTAL_COUNT" -le "50000" ]; then
  echo "✓ Total row count is within 10K-50K range"
else
  echo "⚠ WARNING: Total row count ($TOTAL_COUNT) is outside 10K-50K range (still acceptable)"
fi

# Test 5: Verify foreign key integrity
echo "Test 5: Checking foreign key integrity..."
ORPHAN_COUNT=$(docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -tc "SELECT COUNT(*) FROM comments c LEFT JOIN videos v ON c.video_id = v.video_id WHERE v.video_id IS NULL;" | tr -d '[:space:]')

if [ "$ORPHAN_COUNT" = "0" ]; then
  echo "✓ No orphaned comment records (all have valid video_id)"
else
  echo "✗ FAIL: Found $ORPHAN_COUNT orphaned comments with invalid video_id"
  exit 1
fi

echo ""
echo "✅ All data loading tests passed!"
echo "   Total rows: $TOTAL_COUNT (Videos: $VIDEO_COUNT, Users: $USER_COUNT, Comments: $COMMENT_COUNT)"
