# Deploying Redis Stack on Azure App Service

This document provides step-by-step instructions for deploying your Redis Stack container on Azure App Service with Docker support.

## Overview

Azure App Service is a Platform as a Service (PaaS) offering that supports Docker containers. This deployment method provides:

- **Managed platform**: Less infrastructure to manage
- **Auto-scaling**: Scale up or out based on demand
- **Integration**: Easy integration with other Azure services
- **Persistence**: Uses Azure File Share for data persistence across restarts

## Prerequisites

- Azure CLI installed and configured
- Access to an Azure subscription
- Docker installed locally (for building and pushing the image)
- Your Redis Stack Dockerfile

## Deployment Steps

1. **Create a resource group** (if you don't have one):

   ```bash
   az group create --name redis-stack-rg --location eastus
   ```

2. **Create an Azure Container Registry** to store your Docker image:

   ```bash
   az acr create --name redisstackregistry --resource-group redis-stack-rg --sku Basic --admin-enabled true
   ```

3. **Build and push your Docker image**:

   ```bash
   # Get credentials
   az acr login --name redisstackregistry
   
   # Build and tag the image
   docker build -t redisstackregistry.azurecr.io/redis-stack:latest .
   
   # Push to ACR
   docker push redisstackregistry.azurecr.io/redis-stack:latest
   ```

4. **Create a storage account and file share** for persistent data:

   ```bash
   az storage account create --name redisstackstorage --resource-group redis-stack-rg --location eastus --sku Standard_LRS
   az storage share create --name redisdata --account-name redisstackstorage
   STORAGE_KEY=$(az storage account keys list --resource-group redis-stack-rg --account-name redisstackstorage --query "[0].value" -o tsv)
   ```

5. **Create an App Service Plan**:

   ```bash
   az appservice plan create --name redis-stack-plan --resource-group redis-stack-rg --is-linux --sku P1V2
   ```

6. **Create a Web App for Containers**:

   ```bash
   az webapp create \
     --resource-group redis-stack-rg \
     --plan redis-stack-plan \
     --name redis-stack-app \
     --deployment-container-image-name redisstackregistry.azurecr.io/redis-stack:latest
   ```

7. **Configure persistent storage** using Azure File Share:

   ```bash
   az webapp config storage-account add \
     --resource-group redis-stack-rg \
     --name redis-stack-app \
     --custom-id redis-data \
     --storage-type AzureFiles \
     --account-name redisstackstorage \
     --share-name redisdata \
     --mount-path /data \
     --access-key "$STORAGE_KEY"
   ```

8. **Configure environment variables**:

   ```bash
   az webapp config appsettings set \
     --resource-group redis-stack-rg \
     --name redis-stack-app \
     --settings REDIS_PASSWORD=YOUR_PASSWORD
   ```

9. **Configure ports**:

   ```bash
   az webapp config appsettings set \
     --resource-group redis-stack-rg \
     --name redis-stack-app \
     --settings WEBSITES_PORT=8001
   ```

10. **Access your Redis instance**:
    - RedisInsight: `https://redis-stack-app.azurewebsites.net`
    - Redis: Configure your app to connect to `redis-stack-app.azurewebsites.net:6379`

## Data Persistence

With this configuration, your Redis data is stored on an Azure File Share mounted to the `/data` directory in the container. This ensures:

- All data is preserved when the container restarts
- Your RDB and AOF files are safely stored outside the container
- Data persists even if the App Service is restarted or redeployed

## Network Configuration

For production use, consider:

1. **Configuring App Service networking** for more secure access:
   ```bash
   az webapp vnet-integration add --resource-group redis-stack-rg --name redis-stack-app --vnet <your-vnet> --subnet <your-subnet>
   ```

2. **Setting up Private Endpoints** for direct secure connection:
   ```bash
   az webapp private-endpoint create --resource-group redis-stack-rg --name redis-stack-app ...
   ```

## Scaling Options

Azure App Service provides multiple scaling options:

1. **Vertical scaling** (Scale up): Increase resources for your App Service plan
   ```bash
   az appservice plan update --resource-group redis-stack-rg --name redis-stack-plan --sku P2V2
   ```

2. **Horizontal scaling** (Scale out): Add more instances
   ```bash
   az appservice plan update --resource-group redis-stack-rg --name redis-stack-plan --number-of-workers 3
   ```

## Monitoring and Logging

App Service provides built-in monitoring via:

- Azure Monitor metrics
- Application logs
- Container logs

Access logs from Azure Portal or via CLI:
```bash
az webapp log tail --resource-group redis-stack-rg --name redis-stack-app
```

## Backup Strategy

In addition to the built-in Redis persistence:

1. Configure automated backups for your Azure File Share
2. Schedule regular backups of Redis data using your backup script
3. Consider using geo-replicated storage for disaster recovery
