#!/bin/bash
set -e

# Inspect PostgreSQL database schema
# Shows table structures, foreign keys, and indexes

echo "=== PostgreSQL Schema Inspection ==="
echo ""

echo "Tables in database:"
echo "==================="
docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -c "\dt"
echo ""

echo "Videos table structure:"
echo "======================="
docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -c "\d videos"
echo ""

echo "Users table structure:"
echo "======================"
docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -c "\d users"
echo ""

echo "Comments table structure:"
echo "========================="
docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -c "\d comments"
echo ""

echo "Foreign key relationships:"
echo "=========================="
docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -c "\
  SELECT \
    tc.table_name, \
    kcu.column_name, \
    ccu.table_name AS foreign_table_name, \
    ccu.column_name AS foreign_column_name \
  FROM information_schema.table_constraints AS tc \
  JOIN information_schema.key_column_usage AS kcu \
    ON tc.constraint_name = kcu.constraint_name \
  JOIN information_schema.constraint_column_usage AS ccu \
    ON ccu.constraint_name = tc.constraint_name \
  WHERE tc.constraint_type = 'FOREIGN KEY' \
    AND tc.table_schema = 'public';"
echo ""

echo "Indexes:"
echo "========"
docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -c "\
  SELECT \
    tablename, \
    indexname, \
    indexdef \
  FROM pg_indexes \
  WHERE schemaname = 'public' \
  ORDER BY tablename, indexname;"
