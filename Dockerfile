FROM redis/redis-stack:latest

# Copy the Redis configuration file with persistence settings enabled
COPY redis.conf /redis-stack.conf

# Create directory for Redis logs (for App Insights monitoring)
RUN mkdir -p /var/log/redis && \
    chown redis:redis /var/log/redis

# Set working directory
WORKDIR /data

# Add volume paths
VOLUME ["/data", "/var/log/redis"]

# Expose Redis and RedisInsight ports
EXPOSE 6379 8001

# Use the configuration file from the image
CMD ["redis-stack-server", "/redis-stack.conf"]
