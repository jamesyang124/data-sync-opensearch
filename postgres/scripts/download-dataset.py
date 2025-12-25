#!/usr/bin/env python3
"""
Download YouTube Comment Sentiment dataset from Hugging Face
and select a representative subset (10K-50K records)
"""

import os
import sys
from datasets import load_dataset
import pandas as pd

def main():
    print("Downloading YouTube Comment Sentiment dataset from Hugging Face...")
    print("Dataset: AmaanP314/youtube-comment-sentiment")

    try:
        # Load only the first 30K records to avoid memory issues
        # This prevents downloading the full 1M+ dataset
        subset_size = 30000
        print(f"Downloading first {subset_size} records...")

        dataset = load_dataset(
            "AmaanP314/youtube-comment-sentiment",
            split=f"train[:{subset_size}]"
        )

        print(f"Downloaded: {len(dataset)} records")

        # Convert to pandas DataFrame for easier manipulation
        df_subset = pd.DataFrame(dataset)

        # Save to CSV in sample-data directory
        # When running in container, use /var/lib/postgresql/sample-data
        # When running on host, use postgres/sample-data
        output_dir = os.getenv("SAMPLE_DATA_DIR", "/var/lib/postgresql/sample-data")
        os.makedirs(output_dir, exist_ok=True)

        output_file = os.path.join(output_dir, "youtube-comments-raw.csv")
        df_subset.to_csv(output_file, index=False)

        print(f"✓ Dataset downloaded and saved to: {output_file}")
        print(f"  Rows: {len(df_subset)}")
        print(f"  Columns: {list(df_subset.columns)}")

        return 0

    except Exception as e:
        print(f"✗ Error downloading dataset: {e}", file=sys.stderr)
        return 1

if __name__ == "__main__":
    sys.exit(main())
