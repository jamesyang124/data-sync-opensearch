#!/usr/bin/env python3
"""
Normalize flat YouTube comment CSV into 3-table structure:
- videos: Unique video records
- users: Unique user/channel records
- comments: Comment records with foreign keys
"""

import os
import sys
import pandas as pd
from datetime import datetime

def main():
    print("Normalizing dataset into 3-table structure...")

    try:
        # Load raw CSV
        # When running in container, use /var/lib/postgresql/sample-data
        # When running on host, use postgres/sample-data
        sample_data_dir = os.getenv("SAMPLE_DATA_DIR", "/var/lib/postgresql/sample-data")
        input_file = os.path.join(sample_data_dir, "youtube-comments-raw.csv")

        if not os.path.exists(input_file):
            print(f"✗ Error: Input file not found: {input_file}", file=sys.stderr)
            return 1

        df = pd.read_csv(input_file)
        print(f"Loaded {len(df)} raw records")

        # Extract unique videos
        print("Extracting unique videos...")
        videos = df[['VideoID', 'VideoTitle', 'CategoryID']].drop_duplicates(subset=['VideoID'])
        videos.columns = ['video_id', 'title', 'category']
        videos = videos.dropna(subset=['video_id'])

        print(f"  Found {len(videos)} unique videos")

        # Extract unique users/channels
        print("Extracting unique users/channels...")
        users = df[['AuthorChannelID', 'AuthorName']].drop_duplicates(subset=['AuthorChannelID'])
        users.columns = ['channel_id', 'channel_name']
        users = users.dropna(subset=['channel_id'])

        # Replace null channel names with default value to satisfy NOT NULL constraint
        users['channel_name'] = users['channel_name'].fillna('Unknown User')

        print(f"  Found {len(users)} unique users/channels")

        # Create comments table with foreign keys
        print("Creating comments table with foreign keys...")
        comments = df[[
            'CommentID', 'VideoID', 'AuthorChannelID', 'CommentText',
            'Likes', 'Replies', 'PublishedAt', 'Sentiment', 'CountryCode'
        ]].copy()

        comments.columns = [
            'comment_id', 'video_id', 'channel_id', 'comment_text',
            'likes', 'replies', 'published_at', 'sentiment_label', 'country_code'
        ]

        # Remove duplicates by comment_id (keep first occurrence)
        initial_count = len(comments)
        comments = comments.drop_duplicates(subset=['comment_id'], keep='first')
        duplicate_count = initial_count - len(comments)
        if duplicate_count > 0:
            print(f"  Removed {duplicate_count} duplicate comments")

        # Filter out comments with missing foreign keys
        comments = comments.dropna(subset=['comment_id', 'video_id', 'channel_id'])

        # Ensure foreign key integrity
        valid_video_ids = set(videos['video_id'])
        valid_channel_ids = set(users['channel_id'])

        comments = comments[
            comments['video_id'].isin(valid_video_ids) &
            comments['channel_id'].isin(valid_channel_ids)
        ]

        print(f"  Found {len(comments)} valid comments (removed {initial_count - len(comments)} orphaned records)")

        # Save normalized tables
        output_dir = os.getenv("SAMPLE_DATA_DIR", "/var/lib/postgresql/sample-data")

        videos.to_csv(os.path.join(output_dir, "videos.csv"), index=False)
        users.to_csv(os.path.join(output_dir, "users.csv"), index=False)
        comments.to_csv(os.path.join(output_dir, "comments.csv"), index=False)

        print(f"\n✓ Normalization complete!")
        print(f"  Videos: {len(videos)} rows → videos.csv")
        print(f"  Users: {len(users)} rows → users.csv")
        print(f"  Comments: {len(comments)} rows → comments.csv")
        print(f"  Total: {len(videos) + len(users) + len(comments)} rows")

        return 0

    except Exception as e:
        print(f"✗ Error normalizing data: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    sys.exit(main())
