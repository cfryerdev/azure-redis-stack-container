# Monitoring with Azure Application Insights

This guide explains how to integrate Redis Stack logs with Azure Application Insights for comprehensive monitoring.

## Overview

The integration uses a sidecar container pattern:

1. A Python-based sidecar container reads Redis logs
2. Logs are processed and formatted with Redis-specific metadata
3. Structured logs are sent to Azure Application Insights
4. Redis metrics are available in the Azure portal for monitoring and alerting

## Prerequisites

- An Azure subscription
- An Application Insights resource or a Log Analytics workspace
- The Application Insights connection string

## Implementation Options

### 1. Docker Compose (Local Development)

Add the App Insights sidecar to your `docker-compose.yml` file:

```yaml
version: '3.8'

services:
  redis-stack:
    build:
      context: .
      dockerfile: Dockerfile
    image: azure-redis-stack
    container_name: azure-redis-stack
    ports:
      - "6379:6379"
      - "8001:8001"
    volumes:
      - redis-data:/data
      - redis-logs:/var/log/redis
    restart: always
    environment:
      - REDIS_ARGS=--requirepass ${REDIS_PASSWORD:-redispassword}
    command: redis-stack-server /redis-stack.conf

  app-insights-sidecar:
    build:
      context: ./monitoring/app-insights-sidecar
      dockerfile: Dockerfile
    container_name: redis-app-insights
    depends_on:
      - redis-stack
    volumes:
      - redis-logs:/var/log/redis
    environment:
      - REDIS_LOG_PATH=/var/log/redis/redis.log
      - APP_INSIGHTS_CONNECTION_STRING=${APP_INSIGHTS_CONNECTION_STRING}
      - APP_INSIGHTS_ROLE_NAME=redis-stack
      - APP_INSIGHTS_ROLE_INSTANCE=${HOSTNAME:-redis-1}
      - LOG_LEVEL=info
      - SAMPLING_PERCENTAGE=100

volumes:
  redis-data:
    driver: local
  redis-logs:
    driver: local
```

### 2. Azure Container Instances (ACI)

When deploying to ACI, add the sidecar container to your deployment:

```bash
az container create \
  --resource-group redis-stack-rg \
  --name redis-stack-container \
  --image redis/redis-stack:latest \
  --dns-name-label redis-stack-instance \
  --ports 6379 8001 \
  --environment-variables REDIS_ARGS="--requirepass YOUR_PASSWORD" \
  --azure-file-volume-account-name redisstackstorage \
  --azure-file-volume-account-key "$STORAGE_KEY" \
  --azure-file-volume-share-name redisdata \
  --azure-file-volume-mount-path /data \
  --containers-volume-mounts 'redis-logs'=/var/log/redis \
  --container-group-name redis-stack-group \
  --containers-command-line 'redis-stack-server /redis-stack.conf' \
  --containers 'app-insights-sidecar'='your-acr.azurecr.io/redis-app-insights-sidecar:latest' \
  --containers-command-line 'python log_forwarder.py' \
  --containers-environment-variables \
    'APP_INSIGHTS_CONNECTION_STRING'='InstrumentationKey=your-key' \
    'APP_INSIGHTS_ROLE_NAME'='redis-stack' \
    'REDIS_LOG_PATH'='/var/log/redis/redis.log' \
  --containers-volume-mounts 'redis-logs'=/var/log/redis
```

### 3. Azure Kubernetes Service (AKS)

For AKS, add the sidecar container in your deployment YAML:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-stack
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis-stack
  template:
    metadata:
      labels:
        app: redis-stack
    spec:
      containers:
      - name: redis-stack
        image: redis/redis-stack:latest
        args: ["redis-stack-server", "/redis-stack.conf"]
        ports:
        - containerPort: 6379
          name: redis
        - containerPort: 8001
          name: redisinsight
        env:
        - name: REDIS_ARGS
          value: "--requirepass $(REDIS_PASSWORD)"
        volumeMounts:
        - name: redis-data
          mountPath: /data
        - name: redis-config
          mountPath: /redis-stack.conf
          subPath: redis.conf
        - name: redis-logs
          mountPath: /var/log/redis
          
      - name: app-insights-sidecar
        image: your-acr.azurecr.io/redis-app-insights-sidecar:latest
        env:
        - name: REDIS_LOG_PATH
          value: /var/log/redis/redis.log
        - name: APP_INSIGHTS_CONNECTION_STRING
          valueFrom:
            secretKeyRef:
              name: app-insights-secret
              key: connectionString
        - name: APP_INSIGHTS_ROLE_NAME
          value: redis-stack
        - name: APP_INSIGHTS_ROLE_INSTANCE
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        volumeMounts:
        - name: redis-logs
          mountPath: /var/log/redis
          
      volumes:
      - name: redis-data
        persistentVolumeClaim:
          claimName: redis-data-pvc
      - name: redis-config
        configMap:
          name: redis-config
      - name: redis-logs
        emptyDir: {}
```

## Configuration

### 1. Modify Redis Configuration

Ensure Redis is configured to write logs to a file that can be accessed by the sidecar container:

```
# In redis.conf
loglevel notice
logfile /var/log/redis/redis.log
```

### 2. Environment Variables for the Sidecar

The sidecar container accepts the following environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `REDIS_LOG_PATH` | Path to the Redis log file | `/var/log/redis/redis.log` |
| `LOG_LEVEL` | Log level for the forwarder | `info` |
| `APP_INSIGHTS_CONNECTION_STRING` | App Insights connection string | (required) |
| `APP_INSIGHTS_ROLE_NAME` | Role name in App Insights | `redis-stack` |
| `APP_INSIGHTS_ROLE_INSTANCE` | Instance name | `redis-1` |
| `SAMPLING_PERCENTAGE` | Percentage of logs to send (1-100) | `100` |

### 3. Create Application Insights Resource

If you don't already have an Application Insights resource:

```bash
az monitor app-insights component create \
  --app redis-monitoring \
  --location eastus \
  --resource-group redis-stack-rg \
  --application-type web
```

Get the connection string:

```bash
az monitor app-insights component show \
  --app redis-monitoring \
  --resource-group redis-stack-rg \
  --query connectionString -o tsv
```

## Viewing Redis Logs in Application Insights

After deployment, Redis logs will appear in Application Insights:

1. Go to your Application Insights resource in the Azure portal
2. Navigate to **Logs**
3. Query Redis logs:

```kusto
traces
| where customDimensions.app == "redis-stack"
| project timestamp, message, severityLevel, customDimensions.redis_role, customDimensions.redis_pid
| order by timestamp desc
```

## Creating Alerts

You can create alerts based on Redis log patterns:

1. Go to **Alerts** in Application Insights
2. Create a new alert rule
3. Add a condition based on log search:

```kusto
traces
| where customDimensions.app == "redis-stack"
| where message contains "MISCONF" or message contains "WARNING"
```

## Custom Dashboard

Create a custom dashboard to monitor Redis:

1. Go to **Dashboards** in the Azure portal
2. Create a new dashboard
3. Add Application Insights visualizations:
   - Redis error count chart
   - Memory usage metrics
   - Connection count trends

## Troubleshooting

### Sidecar container can't access Redis logs

- Ensure volumes are correctly mounted
- Check Redis is writing to the expected log file
- Verify file permissions

### No data in Application Insights

- Verify the connection string is correct
- Check the sidecar container logs:
  ```bash
  docker logs redis-app-insights
  ```
- Ensure network connectivity to Azure is available

### Log volume is too high

Adjust the sampling rate to reduce the volume:
```yaml
environment:
  - SAMPLING_PERCENTAGE=10  # Only send 10% of logs
```

## Performance Considerations

- The sidecar container uses minimal resources (typically <100MB RAM)
- Sampling can reduce costs for high-volume Redis instances
- Consider using Log Analytics for long-term log storage and analysis
