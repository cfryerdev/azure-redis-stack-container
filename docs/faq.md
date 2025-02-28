# Frequently Asked Questions (FAQ)

## Table of Contents

- [Data Persistence](#data-persistence)
- [Performance](#performance)
- [Security](#security)
- [Deployment](#deployment)
- [Configuration](#configuration)
- [High Availability](#high-availability)
- [Troubleshooting](#troubleshooting)

## Data Persistence

### Q: If I restart my container in Azure Container Instances or Azure App Service, will I lose my data?

**A:** No, you will not lose data when restarting instances in either deployment option, as long as you've properly configured persistent storage as outlined in our documentation:

- In **Azure Container Instances**, we use an Azure File Share mounted to the `/data` directory of your Redis container
- In **Azure App Service**, we similarly configure storage with an Azure File Share mount

Both configurations ensure:
- Redis data (RDB and AOF files) is stored on external Azure storage, not within the container
- When the container restarts, it reconnects to the same file share
- All your data persists independently of the container's lifecycle

### Q: How often is my data being saved?

**A:** With our default configuration, Redis saves data in two complementary ways:

1. **RDB snapshots** at these intervals:
   - Every 15 minutes if at least 1 key changed
   - Every 5 minutes if at least 10 keys changed
   - Every 1 minute if at least 10,000 keys changed

2. **AOF persistence** that logs every write operation:
   - Set to sync every second (`appendfsync everysec`) for a good balance of performance and safety
   - In this mode, you might lose up to 1 second of data in a worst-case scenario (e.g., power failure)

### Q: What's the difference between RDB and AOF persistence?

**A:** 
- **RDB (Redis Database Backup)** creates point-in-time snapshots of your entire dataset
  - Pros: Smaller files, faster restart recovery, good for backups
  - Cons: Potential for more data loss between snapshots
  
- **AOF (Append Only File)** logs every write operation
  - Pros: Minimal data loss, complete record of all changes
  - Cons: Files grow larger over time, slower than RDB for recovery
  
Our implementation uses both for maximum data protection.

## Performance

### Q: Will the persistence settings impact performance?

**A:** Yes, enabling persistence does have some performance impact:

- **RDB snapshots** have minimal impact during normal operation but can cause brief pauses during the save operation
- **AOF persistence** with `appendfsync everysec` has a small, continuous impact on performance
- **When using Azure File Shares**, there may be additional latency compared to local disk storage

For most use cases, the performance impact is minimal and well worth the data safety. If you're dealing with extreme performance requirements, consider:
1. Tuning the persistence settings to match your workload
2. Using Premium storage in Azure for better performance
3. Exploring Redis Enterprise if you need both extreme performance and data safety

### Q: How do I monitor Redis performance?

**A:** You can monitor Redis performance through:

1. **Redis INFO command**: `redis-cli INFO stats`
2. **RedisInsight UI**: Built-in monitoring graphs
3. **Azure monitoring tools**: If deployed in Azure
4. **Redis SLOWLOG**: `redis-cli SLOWLOG GET 10` to see slow commands

## Security

### Q: Is my Redis data secure in Azure?

**A:** Security depends on your configuration:

1. **Password protection**: Always set a strong Redis password
2. **Network security**: 
   - In ACI: Use VNet integration and private IP addressing
   - In App Service: Use VNet integration and private endpoints
3. **Data encryption**: Azure Storage provides encryption at rest
4. **TLS**: Consider using TLS for Redis connections in production

### Q: Can I use Redis ACLs (Access Control Lists) with this setup?

**A:** Yes, Redis ACLs are supported in Redis 6.0 and above. You can configure them by:

1. Adding ACL rules to your `redis.conf` file
2. Using the `ACL` commands at runtime
3. Setting up user accounts with different permissions

## Deployment

### Q: Which Azure deployment option should I choose?

**A:** It depends on your requirements:

- **Azure Container Instances**: Best for development, testing, or simple production needs. Easiest to set up but with fewer advanced features.
  
- **Azure App Service**: Good middle ground with auto-scaling and integration with other Azure services. Good for small to medium production workloads.
  
- **Azure Kubernetes Service**: Most flexible and powerful option, ideal for production enterprise deployments with high availability requirements.

### Q: Can I migrate between different deployment options without losing data?

**A:** Yes, as long as you maintain the persistence files:

1. Backup your Redis data using the provided backup script
2. Set up the new deployment with appropriate storage
3. Restore your RDB/AOF files to the new deployment's data directory

Detailed migration steps vary between deployment options and are covered in our advanced guides.

## Configuration

### Q: How do I change Redis configuration settings?

**A:** You can change Redis settings by:

1. Modifying the `redis.conf` file and rebuilding your container
2. Setting runtime configuration with `CONFIG SET` commands (note: not all settings can be changed at runtime)
3. Adding command-line arguments to the container startup command

### Q: What versions of Redis and modules are included?

**A:** This project uses the official Redis Stack image which currently includes:

- **Redis**: v7.4.x (Core Redis server)
- **RedisJSON**: v2.4.x (Native JSON data type handling)
- **RediSearch**: v2.6.x (Full-text search capability)
- **RedisGraph**: v2.10.x (Graph database functionality)
- **RedisTimeSeries**: v1.8.x (Time-series data structure)
- **RedisBloom**: v2.4.x (Probabilistic data structures)

You can check the exact versions in your running container with:
```bash
# Redis version
docker exec -it azure-redis-stack redis-cli INFO server | grep redis_version

# Module versions
docker exec -it azure-redis-stack redis-cli MODULE LIST
```

For more detailed information about versions and upgrading, see our [Versions Guide](versions.md).

### Q: Can I use Redis modules like RediSearch or RedisJSON?

**A:** Yes! The Redis Stack image already includes popular modules like:
- RediSearch (full-text search)
- RedisJSON (native JSON handling)
- RedisTimeSeries (time-series data)
- RedisGraph (graph database functionality)
- RedisBloom (probabilistic data structures)

These modules are ready to use without additional configuration.

## High Availability

### Q: Does this setup support Redis replication or clustering?

**A:** The basic setup is for a single Redis instance with persistence. For high availability:

1. **Replication**: You can configure a primary/replica setup by modifying the configuration and running multiple containers
2. **Clustering**: For true clustering, consider using the AKS deployment option
3. **Sentinel**: You can add Redis Sentinel for automatic failover

These configurations require additional setup not covered in the basic documentation.

### Q: What's the recommended backup strategy?

**A:** We recommend a multi-layered approach:

1. Use the provided backup script to regularly export RDB/AOF files
2. Store backups in Azure Blob Storage with appropriate retention policies
3. Consider setting up geo-replication for disaster recovery
4. Test your restore process regularly

## Troubleshooting

### Q: Redis container won't start or crashes shortly after starting

**A:** Common causes include:

1. **Memory issues**: Check if the container has enough memory allocated
2. **Configuration errors**: Validate your `redis.conf` file for syntax errors
3. **Storage permission problems**: Ensure the container has write access to the mounted volume
4. **Port conflicts**: Make sure the required ports aren't already in use

Check the container logs for specific error messages:
```bash
docker logs azure-redis-stack
# or in Azure:
az container logs --resource-group <your-rg> --name <your-container>
```

### Q: I'm getting "MISCONF" errors about Redis being configured to save RDB snapshots

**A:** This usually happens when Redis can't write to the data directory. Check:

1. The volume is properly mounted
2. The container has write permissions to the mounted directory
3. There's sufficient disk space available

You can temporarily disable this check with:
```
redis-cli CONFIG SET stop-writes-on-bgsave-error no
```
But you should fix the underlying issue to ensure data persistence.
