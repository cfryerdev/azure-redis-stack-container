# Azure Redis Stack - Infrastructure as Code

This directory contains Bicep templates to deploy the Redis Stack solution to various Azure services. These templates allow you to easily provision the entire infrastructure required to run Redis Stack with persistence and monitoring capabilities.

## Deployment Options

You can deploy Redis Stack to the following Azure services:

1. **Azure Container Instances (ACI)** - Simple serverless container deployment
2. **Azure App Service** - PaaS deployment with Web App for Containers
3. **Azure Kubernetes Service (AKS)** - Fully managed Kubernetes for larger deployments

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed
- Azure subscription
- Bash shell (for running the deployment script)

## Quick Start

1. Edit the `parameters.json` file to customize your deployment
2. Run the deployment script with one of the following options:

```bash
# Deploy to Azure Container Instances (ACI) - default
./deploy.sh --resource-group redis-stack-rg --location eastus

# Deploy to App Service
./deploy.sh --resource-group redis-stack-rg --location eastus --type app-service

# Deploy to AKS
./deploy.sh --resource-group redis-stack-rg --location eastus --type aks

# Deploy with custom container resources
./deploy.sh --resource-group redis-stack-rg --type aci --memory 4 --cpu 2

# Update parameters without deploying
./deploy.sh --type app-service --update-params

# Provide Redis password securely via command line
./deploy.sh --resource-group redis-stack-rg --type aci --password "YourSecurePassword123!"
```

For complete documentation on all deployment options, see the [Comprehensive Deployment Guide](../deploy.md).

## Deployment Parameters

Customize your deployment by editing the `parameters.json` file:

| Parameter | Description |
|-----------|-------------|
| `deploymentName` | Base name for your resources |
| `location` | Azure region for deployment |
| `environmentType` | Environment type (dev, test, prod) |
| `deploymentType` | Target service (aci, app-service, aks) |
| `redisPassword` | Password for Redis (change this!) |
| `storageAccountName` | Storage account for data persistence |
| `enableAppInsights` | Whether to enable monitoring |
| `containerCpuCores` | CPU cores for the container |
| `containerMemoryGb` | Memory in GB for the container |
| `enableVirtualNetwork` | Whether to use a VNet |
| `appServiceConfig` | App Service-specific configuration |
| `aciConfig` | ACI-specific configuration |

## Infrastructure Components

The Bicep templates create the following resources:

- **Storage Account and File Share** for data persistence
- **Container Instance, App Service, or AKS** depending on deployment type
- **Application Insights** for monitoring (if enabled)
- **Virtual Network** resources (if enabled)

## Detailed Deployment Options

### Azure Container Instances (ACI)

ACI provides a simple way to run Redis Stack as a containerized application:

```bash
./deploy.sh --type aci
```

### Azure App Service

App Service provides a PaaS environment for running Redis Stack:

```bash
./deploy.sh --type app-service
```

### Azure Kubernetes Service (AKS)

AKS offers a managed Kubernetes environment for more advanced deployments:

```bash
./deploy.sh --type aks
```

After AKS deployment, you'll need to manually apply the generated Kubernetes manifests.

## Customizing the Deployment

For more advanced customization, you can modify the Bicep templates directly:

- `main.bicep` - Main deployment template
- `modules/common.bicep` - Common resources like storage
- `modules/network.bicep` - Network resources
- `modules/aci.bicep` - ACI-specific deployment
- `modules/app-service.bicep` - App Service-specific deployment
- `modules/aks.bicep` - AKS-specific deployment

## Security Considerations

- Change the default Redis password in the parameters file
- For production deployments, enable a Virtual Network
- Consider using Private Endpoints for storage accounts
- Review the generated NSG rules for network security

## Monitoring

If you enable Application Insights, you can:

- View Redis logs and performance in the Azure portal
- Set up alerts for critical events
- Create custom dashboards to monitor your Redis instance

## Persistence

All deployment options configure Redis with:

- RDB persistence (periodic snapshots)
- AOF persistence (write-ahead log)
- External storage for data durability
