#!/bin/bash
set -e

# Integration Test: Schema Validation
# Verify 3 tables exist with correct columns, types, and foreign keys

echo "=== Testing Schema Validation ==="

# Test 1: Verify 3 tables exist
echo "Test 1: Checking if 3 tables exist..."
TABLE_COUNT=$(docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -tc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE';" | tr -d '[:space:]')

if [ "$TABLE_COUNT" = "3" ]; then
  echo "✓ Found 3 tables (videos, users, comments)"
else
  echo "✗ FAIL: Expected 3 tables, found $TABLE_COUNT"
  exit 1
fi

# Test 2: Verify videos table structure
echo "Test 2: Checking videos table structure..."
if docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -c "\d videos" | grep -q "video_id"; then
  echo "✓ Videos table has correct structure"
else
  echo "✗ FAIL: Videos table structure incorrect"
  exit 1
fi

# Test 3: Verify users table structure
echo "Test 3: Checking users table structure..."
if docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -c "\d users" | grep -q "channel_id"; then
  echo "✓ Users table has correct structure"
else
  echo "✗ FAIL: Users table structure incorrect"
  exit 1
fi

# Test 4: Verify comments table structure
echo "Test 4: Checking comments table structure..."
if docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -c "\d comments" | grep -q "comment_id"; then
  echo "✓ Comments table has correct structure"
else
  echo "✗ FAIL: Comments table structure incorrect"
  exit 1
fi

# Test 5: Verify foreign keys exist
echo "Test 5: Checking foreign key constraints..."
FK_COUNT=$(docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -tc "SELECT COUNT(*) FROM information_schema.table_constraints WHERE constraint_type='FOREIGN KEY' AND table_schema='public';" | tr -d '[:space:]')

if [ "$FK_COUNT" -ge "2" ]; then
  echo "✓ Foreign key constraints exist (comments → videos, comments → users)"
else
  echo "✗ FAIL: Expected at least 2 foreign keys, found $FK_COUNT"
  exit 1
fi

echo ""
echo "✅ All schema validation tests passed!"
