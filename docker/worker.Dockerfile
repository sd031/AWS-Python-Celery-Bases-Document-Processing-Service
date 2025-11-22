FROM python:3.11-slim

WORKDIR /app

# Install system dependencies including ffmpeg and ImageMagick
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    ffmpeg \
    imagemagick \
    poppler-utils \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Install additional packages for processing
RUN pip install --no-cache-dir \
    pdf2image==1.16.3 \
    PyPDF2==3.0.1

# Copy application code
COPY worker/ ./worker/
COPY api/config.py ./api/config.py
COPY api/__init__.py ./api/__init__.py

# Create temp directory
RUN mkdir -p /tmp

# Run Celery worker
CMD ["celery", "-A", "worker.celery_app", "worker", "--loglevel=info", "--concurrency=2"]
