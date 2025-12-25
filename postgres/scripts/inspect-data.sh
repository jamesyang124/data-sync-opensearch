#!/bin/bash
set -e

# Inspect PostgreSQL database sample data
# Shows first 10 rows from each table

echo "=== PostgreSQL Sample Data Inspection ==="
echo ""

echo "Sample videos (first 10):"
echo "========================="
docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -c "\
  SELECT video_id, title, category \
  FROM videos \
  LIMIT 10;"
echo ""

echo "Sample users (first 10):"
echo "========================"
docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -c "\
  SELECT channel_id, channel_name \
  FROM users \
  LIMIT 10;"
echo ""

echo "Sample comments (first 10):"
echo "==========================="
docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -c "\
  SELECT \
    comment_id, \
    video_id, \
    channel_id, \
    LEFT(comment_text, 50) AS comment_preview, \
    likes, \
    sentiment_label \
  FROM comments \
  LIMIT 10;"
echo ""

echo "Table statistics:"
echo "================="
docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -c "\
  SELECT \
    'videos' AS table_name, \
    COUNT(*) AS row_count \
  FROM videos \
  UNION ALL \
  SELECT \
    'users' AS table_name, \
    COUNT(*) AS row_count \
  FROM users \
  UNION ALL \
  SELECT \
    'comments' AS table_name, \
    COUNT(*) AS row_count \
  FROM comments;"
