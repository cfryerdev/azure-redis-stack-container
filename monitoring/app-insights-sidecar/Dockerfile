# Dockerfile for Redis Log Forwarder to App Insights
FROM python:3.10-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the log forwarder script
COPY log_forwarder.py .

# Set environment variables with defaults
ENV REDIS_LOG_PATH=/var/log/redis/redis.log
ENV LOG_LEVEL=info
ENV APP_INSIGHTS_CONNECTION_STRING=""
ENV APP_INSIGHTS_ROLE_NAME="redis-stack"
ENV APP_INSIGHTS_ROLE_INSTANCE="redis-1"
ENV SAMPLING_PERCENTAGE=100

# Run the log forwarder
CMD ["python", "log_forwarder.py"]
