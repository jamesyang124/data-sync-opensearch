#!/bin/bash
set -e

# Load YouTube Comment Sentiment data into PostgreSQL
# Orchestrates: download → normalize → bulk insert

echo "=== PostgreSQL Data Loading Script ==="
echo ""

# Check if data is already loaded
echo "Checking if database already has data..."
ROW_COUNT=$(docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -tc "SELECT COUNT(*) FROM comments;" 2>/dev/null | tr -d '[:space:]' || echo "0")

if [ "$ROW_COUNT" -gt "0" ]; then
  echo "✓ Database already has $ROW_COUNT comments. Skipping data load."
  echo "  (Run 'make reset' to reload fresh data)"
  exit 0
fi

echo "Database is empty. Loading sample data..."
echo ""

# Check if data exists in mounted volume (persists across container restarts)
echo "Step 1: Checking for cached dataset..."
if ! docker compose exec -T postgres test -f /var/lib/postgresql/sample-data/videos.csv; then
  echo "  No cached data found. Downloading from Hugging Face..."

  # Download dataset (runs inside container)
  if ! docker compose exec -T postgres python3 /usr/local/bin/postgres-scripts/download-dataset.py; then
    echo "✗ Failed to download dataset"
    exit 1
  fi
  echo ""

  echo "  Normalizing data into 3-table structure..."
  if ! docker compose exec -T postgres python3 /usr/local/bin/postgres-scripts/normalize-data.py; then
    echo "✗ Failed to normalize data"
    exit 1
  fi
else
  echo "  ✓ Using cached data from previous run"
fi
echo ""

# Step 2: Bulk insert into PostgreSQL
echo "Step 2: Bulk inserting data into PostgreSQL..."

# Clear any existing data (handles partial load failures)
echo "  Clearing any existing data..."
docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -c "\
  TRUNCATE TABLE comments, users, videos CASCADE;"

# Copy videos (from mounted volume inside container)
echo "  Loading videos..."
docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -c "\
  COPY videos(video_id, title, category) \
  FROM '/var/lib/postgresql/sample-data/videos.csv' \
  WITH (FORMAT csv, HEADER true);"

# Copy users
echo "  Loading users..."
docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -c "\
  COPY users(channel_id, channel_name) \
  FROM '/var/lib/postgresql/sample-data/users.csv' \
  WITH (FORMAT csv, HEADER true);"

# Copy comments
echo "  Loading comments..."
docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -c "\
  COPY comments(comment_id, video_id, channel_id, comment_text, likes, replies, published_at, sentiment_label, country_code) \
  FROM '/var/lib/postgresql/sample-data/comments.csv' \
  WITH (FORMAT csv, HEADER true);"

echo ""
echo "Step 3: Verifying data load..."

# Get final counts
VIDEO_COUNT=$(docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -tc "SELECT COUNT(*) FROM videos;" | tr -d '[:space:]')
USER_COUNT=$(docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -tc "SELECT COUNT(*) FROM users;" | tr -d '[:space:]')
COMMENT_COUNT=$(docker compose exec -T postgres psql -U "${POSTGRES_USER:-app}" -d "${POSTGRES_DB:-app}" -tc "SELECT COUNT(*) FROM comments;" | tr -d '[:space:]')
TOTAL_COUNT=$((VIDEO_COUNT + USER_COUNT + COMMENT_COUNT))

echo "✓ Data load complete!"
echo "  Videos: $VIDEO_COUNT rows"
echo "  Users: $USER_COUNT rows"
echo "  Comments: $COMMENT_COUNT rows"
echo "  Total: $TOTAL_COUNT rows"
echo ""
echo "Run 'make health' to verify database status"
