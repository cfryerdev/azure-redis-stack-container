# Redis Stack Versions

This document provides information about the versions of Redis and modules included in the Redis Stack image used by this project.

## Current Versions

Our Dockerfile uses `redis/redis-stack:latest`, which as of February 2025 includes:

| Component | Version | Description |
|-----------|---------|-------------|
| Redis | 7.4.x | The core Redis server |
| RedisJSON | 2.4.x | Native JSON data type and operations |
| RediSearch | 2.6.x | Full-text search engine for Redis |
| RedisGraph | 2.10.x | Graph database functionality |
| RedisTimeSeries | 1.8.x | Time-series data structure |
| RedisBloom | 2.4.x | Probabilistic data structures |

## Checking Installed Versions

You can verify the exact versions installed in your running container using these commands:

```bash
# Check Redis version
docker exec -it azure-redis-stack redis-cli INFO server | grep redis_version

# Check module versions
docker exec -it azure-redis-stack redis-cli MODULE LIST
```

In Azure deployments, replace `docker exec` with the appropriate command for your deployment environment.

## Version Update Policy

The Redis Stack image is updated regularly by the Redis team to include security patches and feature updates. We recommend:

1. **Pinning to specific versions** in production environments for stability
2. **Regular updates** to incorporate security fixes
3. **Testing upgrades** in a non-production environment before updating production

## Upgrading

To upgrade to a newer version of Redis Stack:

1. Update the Dockerfile to specify the desired version:
   ```
   FROM redis/redis-stack:7.2.0-v0.x.0
   ```
   (Replace with the actual version number)

2. Rebuild and redeploy:
   ```
   docker-compose down
   docker-compose build
   docker-compose up -d
   ```

3. Verify the new version is running:
   ```
   docker exec -it azure-redis-stack redis-cli INFO server
   ```

## Version Compatibility

When upgrading, be aware of compatibility concerns:

1. **RDB/AOF Format Changes**: Redis persistence files may not be compatible between major versions
2. **API Changes**: Module APIs might change between versions
3. **Configuration Options**: Some configuration options might be deprecated or added

Always consult the [Redis release notes](https://github.com/redis/redis/releases) and [Redis Stack documentation](https://redis.io/docs/stack/) for specific version compatibility information.

## Extended Support

Redis Stack incorporates Redis and additional modules developed by Redis Ltd. For production use with extended support and additional enterprise features, consider:

1. **Redis Enterprise**: Commercial offering with 24/7 support
2. **Redis Enterprise Cloud**: Fully-managed Redis service in the cloud
3. **Redis Enterprise Software**: Self-managed software for on-premises or private cloud deployments
