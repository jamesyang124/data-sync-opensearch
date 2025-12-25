# Multi-stage build for PostgreSQL with pre-built dataset
# Stage 1: Download and normalize dataset (build-time only)
FROM python:3.12-slim AS dataset-builder

# Install Python packages for data processing
COPY postgres/requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt

# Copy data processing scripts
COPY postgres/scripts/download-dataset.py /tmp/download-dataset.py
COPY postgres/scripts/normalize-data.py /tmp/normalize-data.py

# Download and normalize dataset at build time
RUN mkdir -p /dataset && \
    echo "Downloading dataset from Hugging Face..." && \
    SAMPLE_DATA_DIR=/dataset python3 /tmp/download-dataset.py && \
    echo "Normalizing data into 3-table structure..." && \
    SAMPLE_DATA_DIR=/dataset python3 /tmp/normalize-data.py && \
    echo "Dataset preparation complete!" && \
    ls -lh /dataset/*.csv

# Stage 2: PostgreSQL with pre-built CSV data (no Python data processing libraries)
FROM postgres:14-alpine

# Copy pre-built CSV files from builder stage
COPY --from=dataset-builder /dataset/*.csv /var/lib/postgresql/sample-data/

# Create directories
RUN mkdir -p /var/lib/postgresql/sample-data

ENV SAMPLE_DATA_DIR="/var/lib/postgresql/sample-data"

# Verify CSV files exist
RUN echo "Verifying CSV files in final image..." && \
    ls -lh /var/lib/postgresql/sample-data/ && \
    wc -l /var/lib/postgresql/sample-data/*.csv
