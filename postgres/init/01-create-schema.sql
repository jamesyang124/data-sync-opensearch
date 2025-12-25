-- PostgreSQL Schema for YouTube Comment Sentiment Dataset
-- Normalized 3-table structure: videos, users, comments

-- Videos table: Unique video records
CREATE TABLE IF NOT EXISTS videos (
    video_id VARCHAR(255) PRIMARY KEY,
    title TEXT NOT NULL,
    category VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Users/Channels table: Unique user/channel records
CREATE TABLE IF NOT EXISTS users (
    channel_id VARCHAR(255) PRIMARY KEY,
    channel_name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Comments table: Comment records with foreign keys
CREATE TABLE IF NOT EXISTS comments (
    comment_id VARCHAR(255) PRIMARY KEY,
    video_id VARCHAR(255) NOT NULL REFERENCES videos(video_id) ON DELETE CASCADE,
    channel_id VARCHAR(255) NOT NULL REFERENCES users(channel_id) ON DELETE CASCADE,
    comment_text TEXT NOT NULL,
    likes INTEGER DEFAULT 0,
    replies INTEGER DEFAULT 0,
    published_at TIMESTAMP,
    sentiment_label VARCHAR(50),
    country_code VARCHAR(10),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO app;
