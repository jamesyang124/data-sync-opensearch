# Multi-stage build for PostgreSQL with Python 3.12
# Stage 1: Build Python environment
FROM python:3.12-alpine AS python-deps

# Verify Python version during build
RUN python3 --version && \
    echo "Python site-packages location:" && \
    python3 -c "import site; print(site.getsitepackages())"

# Install build dependencies
RUN apk add --no-cache \
    gcc \
    musl-dev \
    postgresql-dev

# Copy and install Python packages
COPY postgres/requirements.txt /tmp/requirements.txt
RUN echo "Installing packages for Python 3.12..." && \
    pip3 install --no-cache-dir -r /tmp/requirements.txt && \
    echo "Verifying NumPy installation:" && \
    python3 -c "import numpy; print(f'NumPy version: {numpy.__version__}')" && \
    echo "NumPy compiled modules:" && \
    find /usr/local/lib/python3.12/site-packages/numpy -name "*.so" | head -5

# Stage 2: PostgreSQL with Python 3.12
FROM postgres:14-alpine

# Install Python 3.12 and runtime dependencies
RUN apk add --no-cache \
    python3 \
    py3-pip \
    libpq && \
    echo "Stage 2 Python version:" && \
    python3 --version && \
    echo "Python sys.path:" && \
    python3 -c "import sys; print('\n'.join(sys.path))"

# Copy Python packages from builder stage to Alpine's site-packages location
# Alpine python3 looks in /usr/lib/python3.12/site-packages
COPY --from=python-deps /usr/local/lib/python3.12/site-packages/ /usr/lib/python3.12/site-packages/

# Verify packages work in final stage
RUN echo "Verifying Python packages in final stage:" && \
    python3 -c "import sys; print(f'Python: {sys.version}')" && \
    python3 -c "import numpy; print(f'NumPy: {numpy.__version__}')" && \
    python3 -c "import pandas; print(f'Pandas: {pandas.__version__}')" && \
    python3 -c "import datasets; print(f'Datasets: {datasets.__version__}')"

# Copy scripts into container
COPY postgres/scripts/ /usr/local/bin/postgres-scripts/
RUN chmod +x /usr/local/bin/postgres-scripts/*.sh /usr/local/bin/postgres-scripts/*.py

# Create directories for data
RUN mkdir -p /var/lib/postgresql/sample-data

# Environment for scripts
ENV PATH="/usr/local/bin/postgres-scripts:${PATH}"
ENV SAMPLE_DATA_DIR="/var/lib/postgresql/sample-data"

# Use default postgres entrypoint and command
