# Deploying Redis Stack on Azure Container Instances

This document provides step-by-step instructions for deploying your Redis Stack container on Azure Container Instances (ACI).

## Overview

Azure Container Instances is a serverless container platform that lets you run container workloads on-demand without managing VMs or clusters. This deployment method is:

- **Simple**: Minimal configuration required
- **Cost-effective**: Pay only for the resources you use
- **Persistent**: Uses Azure File Share for data persistence across restarts

## Prerequisites

- Azure CLI installed and configured
- Access to an Azure subscription
- Your Redis Stack container image (or using the official Redis Stack image)

## Deployment Steps

1. **Create a resource group** (if you don't have one):

   ```bash
   az group create --name redis-stack-rg --location eastus
   ```

2. **Create an Azure File Share** for persistent storage:

   ```bash
   az storage account create --name redisstackstorage --resource-group redis-stack-rg --location eastus --sku Standard_LRS
   az storage share create --name redisdata --account-name redisstackstorage
   ```

3. **Get storage account key**:

   ```bash
   STORAGE_KEY=$(az storage account keys list --resource-group redis-stack-rg --account-name redisstackstorage --query "[0].value" -o tsv)
   ```

4. **Deploy the container**:

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
     --azure-file-volume-mount-path /data
   ```

5. **Access your Redis instance**:

   ```
   redis-cli -h <your-container-dns-name>.eastus.azurecontainer.io -p 6379 -a YOUR_PASSWORD
   ```
   
   Access RedisInsight at: `http://<your-container-dns-name>.eastus.azurecontainer.io:8001`

## Data Persistence

With this configuration, your Redis data is stored on an Azure File Share mounted to the `/data` directory in the container. This ensures:

- All data is preserved when the container restarts
- Your RDB and AOF files are safely stored outside the container
- Data persists even if the container is deleted and recreated

## Network Security

By default, the Redis and RedisInsight ports are exposed to the internet. In a production environment, consider:

1. Adding a virtual network for your container
2. Using private IP addresses
3. Implementing network security groups to restrict access

## Monitoring and Management

Monitor your container through:

- Azure Portal under Container Instances
- Azure Monitor metrics
- Container logs through the Azure CLI:
  ```bash
  az container logs --resource-group redis-stack-rg --name redis-stack-container
  ```

## Scaling Considerations

ACI is a single-instance deployment. If you need clustering or high availability:

1. Consider using AKS for a more robust solution
2. Implement application-level replication if needed
3. Use multiple read replicas for read scaling

## Cost Management

ACI charges based on:

- Container CPU and memory allocation
- Storage used by the Azure File Share

Consider right-sizing your container and monitoring usage to optimize costs.
