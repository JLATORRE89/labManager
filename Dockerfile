FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    openssh-client \
    sshpass \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p /app/completedLabs /app/logs /app/vm_configs

# Set permissions
RUN chmod +x scripts/*.sh scripts/checklabs/*.sh scripts/createlabs/*.sh 2>/dev/null || true

# Create non-root user for security
RUN useradd -m -u 1000 labmanager && \
    chown -R labmanager:labmanager /app

USER labmanager

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:5000/api/health')" || exit 1

# Default command
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", "--worker-class", "gevent", "--timeout", "120", "app:app"]
