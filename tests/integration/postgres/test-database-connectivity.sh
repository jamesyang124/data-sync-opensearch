#!/bin/bash
set -e

# Integration Test: Database Connectivity
# Verify PostgreSQL container is running and accepting connections

echo "=== Testing Database Connectivity ==="

# Test 1: Check pg_isready
echo "Test 1: Checking PostgreSQL readiness..."
if docker compose exec -T postgres pg_isready -U "${POSTGRES_USER:-app}" >/dev/null 2>&1; then
  echo "✓ PostgreSQL is ready"
else
  echo "✗ FAIL: PostgreSQL is not ready"
  exit 1
fi

# Test 2: Test psql connection
echo "Test 2: Testing psql connection..."
if docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -c "SELECT 1;" >/dev/null 2>&1; then
  echo "✓ psql connection successful"
else
  echo "✗ FAIL: psql connection failed"
  exit 1
fi

# Test 3: Verify database exists
echo "Test 3: Verifying database exists..."
DB_EXISTS=$(docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -tc "SELECT 1 FROM pg_database WHERE datname='${POSTGRES_DB:-app}';" | tr -d '[:space:]')
if [ "$DB_EXISTS" = "1" ]; then
  echo "✓ Database '${POSTGRES_DB:-app}' exists"
else
  echo "✗ FAIL: Database '${POSTGRES_DB:-app}' does not exist"
  exit 1
fi

echo ""
echo "✅ All database connectivity tests passed!"
