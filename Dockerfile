FROM redis/redis-stack:latest

# Set working directory
WORKDIR /data

# Copy custom Redis configuration if needed
COPY redis.conf /redis-stack.conf

# Create volume for Redis data
VOLUME /data

# Expose Redis port
EXPOSE 6379
# Expose RedisInsight port
EXPOSE 8001

# Command to run Redis with the custom configuration
CMD ["redis-stack-server", "/redis-stack.conf"]
