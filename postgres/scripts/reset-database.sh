#!/bin/bash
set -e

# Reset PostgreSQL database to initial state with fresh sample data

echo "=== PostgreSQL Database Reset ==="
echo ""

# Get current row counts before reset
echo "Current database state:"
VIDEO_COUNT_BEFORE=$(docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -tc "SELECT COUNT(*) FROM videos;" 2>/dev/null | tr -d '[:space:]' || echo "0")
USER_COUNT_BEFORE=$(docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -tc "SELECT COUNT(*) FROM users;" 2>/dev/null | tr -d '[:space:]' || echo "0")
COMMENT_COUNT_BEFORE=$(docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -tc "SELECT COUNT(*) FROM comments;" 2>/dev/null | tr -d '[:space:]' || echo "0")

echo "  Videos: $VIDEO_COUNT_BEFORE rows"
echo "  Users: $USER_COUNT_BEFORE rows"
echo "  Comments: $COMMENT_COUNT_BEFORE rows"
echo ""

# Drop and recreate database
echo "Resetting database..."
docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d postgres -c "DROP DATABASE IF EXISTS ${POSTGRES_DB:-app};" >/dev/null
docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d postgres -c "CREATE DATABASE ${POSTGRES_DB:-app};" >/dev/null
echo "✓ Database dropped and recreated"
echo ""

# Re-run init scripts
echo "Re-applying schema..."
docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -f /docker-entrypoint-initdb.d/01-create-schema.sql >/dev/null
docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -f /docker-entrypoint-initdb.d/02-create-indexes.sql >/dev/null
echo "✓ Schema recreated"
echo ""

# Reload data
echo "Reloading sample data..."
bash postgres/scripts/load-data.sh
echo ""

# Get new row counts
echo "New database state:"
VIDEO_COUNT_AFTER=$(docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -tc "SELECT COUNT(*) FROM videos;" | tr -d '[:space:]')
USER_COUNT_AFTER=$(docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -tc "SELECT COUNT(*) FROM users;" | tr -d '[:space:]')
COMMENT_COUNT_AFTER=$(docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -tc "SELECT COUNT(*) FROM comments;" | tr -d '[:space:]')

echo "  Videos: $VIDEO_COUNT_AFTER rows (was $VIDEO_COUNT_BEFORE)"
echo "  Users: $USER_COUNT_AFTER rows (was $USER_COUNT_BEFORE)"
echo "  Comments: $COMMENT_COUNT_AFTER rows (was $COMMENT_COUNT_BEFORE)"
echo ""
echo "✅ Database reset complete!"
