FROM python:3.11-slim

# Build arguments
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

# Labels for metadata
LABEL org.opencontainers.image.created=$BUILD_DATE \
      org.opencontainers.image.source="https://github.com/Jacob-Tate/docker-swarm-discord-monitor" \
      org.opencontainers.image.version=$VERSION \
      org.opencontainers.image.revision=$VCS_REF \
      org.opencontainers.image.vendor="Jacob Tate" \
      org.opencontainers.image.title="Docker Swarm Discord Monitor" \
      org.opencontainers.image.description="Monitor Docker Swarm container events and send Discord notifications" \
      org.opencontainers.image.licenses="MIT"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY docker-monitor.py .

# Create non-root user
RUN groupadd -r monitor && useradd -r -g monitor monitor

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import docker; docker.from_env().ping()" || exit 1

# Switch to non-root user
USER monitor

# Run the application
CMD ["python", "docker-monitor.py"]
