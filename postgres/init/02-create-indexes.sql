-- Indexes for PostgreSQL YouTube Comment Dataset
-- Optimize queries and foreign key lookups

-- Indexes on foreign keys (for join performance)
CREATE INDEX IF NOT EXISTS idx_comments_video_id ON comments(video_id);
CREATE INDEX IF NOT EXISTS idx_comments_channel_id ON comments(channel_id);

-- Indexes on commonly queried fields
CREATE INDEX IF NOT EXISTS idx_comments_published_at ON comments(published_at);
CREATE INDEX IF NOT EXISTS idx_comments_sentiment ON comments(sentiment_label);
CREATE INDEX IF NOT EXISTS idx_videos_category ON videos(category);
CREATE INDEX IF NOT EXISTS idx_comments_country ON comments(country_code);

-- Composite index for common queries (video + time range)
CREATE INDEX IF NOT EXISTS idx_comments_video_time ON comments(video_id, published_at DESC);
