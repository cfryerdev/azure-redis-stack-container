# Azure Redis Stack Deployment Guide

This document provides comprehensive instructions for deploying the Azure Redis Stack solution using the flexible infrastructure-as-code templates included in this project.

## Deployment Options

Azure Redis Stack offers multiple deployment options to fit your specific needs:

| Deployment Type | Description | Best For |
|-----------------|-------------|----------|
| **Azure Container Instances (ACI)** | Serverless container deployment | Development, testing, simple workloads |
| **Azure App Service** | PaaS deployment with Web App for Containers | Production workloads, simplified management |
| **Azure Kubernetes Service (AKS)** | Managed Kubernetes deployment | Enterprise workloads, high availability, scaling |

## Prerequisites

Before deploying, ensure you have:

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed and logged in
- An active Azure subscription
- [Bicep CLI](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/install) installed (comes with recent Azure CLI versions)
- Bash shell environment (Windows users can use WSL or Git Bash)
- (Optional) `jq` for advanced parameter file manipulation

## Quick Start

The simplest way to deploy is using the provided deployment script:

```bash
# Navigate to the infrastructure directory
cd infrastructure

# Deploy to Azure Container Instances (default)
./deploy.sh --resource-group redis-stack-rg --location eastus

# Or deploy to App Service
./deploy.sh --resource-group redis-stack-rg --location eastus --type app-service
```

## Advanced Deployment Options

The deployment script supports many options for customizing your deployment:

```bash
./deploy.sh [options]
```

### Command Line Options

| Option | Description |
|--------|-------------|
| `-g, --resource-group` | Resource group name (required) |
| `-l, --location` | Azure region (default: eastus) |
| `-e, --environment` | Environment type: dev, test, prod (default: dev) |
| `-t, --type` | Deployment type: aci, app-service, aks (default: aci) |
| `-n, --name` | Base name for deployment resources (default: redisstack) |
| `-p, --parameters` | Path to parameters file (default: parameters.json) |
| `-u, --update-params` | Only update parameters file, don't deploy |
| `--password` | Set Redis password (more secure than in parameters file) |
| `--memory` | Set container memory in GB |
| `--cpu` | Set container CPU cores |
| `-y, --yes` | Skip confirmation prompts |
| `-h, --help` | Show help message |

### Example Commands

Deploy to Azure Container Instances with custom resources:

```bash
./deploy.sh --resource-group redis-stack-rg --type aci --memory 4 --cpu 2
```

Deploy to App Service with specific configuration:

```bash
./deploy.sh --resource-group redis-stack-rg --type app-service --environment prod --name myredisstack
```

Deploy to AKS with secure password handling:

```bash
./deploy.sh --resource-group redis-stack-rg --type aks --password "YourSecurePassword123!"
```

Update parameters file without deploying:

```bash
./deploy.sh --type app-service --update-params
```

## Configuration Parameters

The `parameters.json` file contains all configurable settings for your deployment. Key parameters include:

### General Parameters

- `deploymentName`: Base name for your resources
- `location`: Azure region for deployment
- `environmentType`: Environment type (dev, test, prod)
- `deploymentType`: Target service (aci, app-service, aks)
- `redisPassword`: Password for Redis access
- `enableAppInsights`: Toggle monitoring integration
- `enableVirtualNetwork`: Toggle network integration

### App Service Configuration

```json
"appServiceConfig": {
  "value": {
    "skuName": "P1v2",
    "skuTier": "PremiumV2",
    "alwaysOn": true
  }
}
```

### Azure Container Instances Configuration

```json
"aciConfig": {
  "value": {
    "restartPolicy": "Always"
  }
}
```

## Deployment Environments

The solution supports different environment types that adjust resource allocations and configurations:

- **Development (dev)**: Minimal resources for development and testing
- **Testing (test)**: Moderate resources for QA environments
- **Production (prod)**: Full resources for production workloads

## Network Integration

Enable virtual network integration by setting `enableVirtualNetwork` to `true` in your parameters file. This provides:

- Network isolation for your Redis instance
- Private communication between services
- Advanced network security controls

## Security Considerations

- Always change the default Redis password
- For production deployments, enable a Virtual Network
- Use the `--password` option to provide passwords directly rather than storing in parameter files
- Consider using Key Vault for storing sensitive information
- Review generated NSG rules for network security
- Enable diagnostic settings for audit logs

## Monitoring and Diagnostics

When `enableAppInsights` is set to `true`, the deployment includes:

- Azure Application Insights resource
- Monitoring sidecar container (for ACI and App Service)
- Log collection and metrics configuration
- Basic alerts setup

## Troubleshooting

### Common Issues

1. **Deployment Fails with "Resource Group Not Found"**
   - Ensure the resource group exists or add `--create-resource-group` option

2. **Container Fails to Start**
   - Check if the memory and CPU allocations are sufficient
   - Verify storage account connectivity
   - Check Redis password configuration

3. **Cannot Connect to Redis**
   - Verify network security group rules
   - Check if the container is healthy
   - Ensure you're using the correct connection string and password

### Getting Help

For additional assistance:

- Check the detailed deployment logs in the Azure Portal
- Review the Azure CLI output for error messages
- Open an issue in the GitHub repository

## CI/CD Integration

For CI/CD pipelines, use the `-y/--yes` flag to skip confirmation prompts:

```bash
./deploy.sh --resource-group redis-stack-rg --type aci --yes
```

## Next Steps

After deployment:

1. Test connectivity to your Redis instance
2. Configure your application to use the Redis connection string
3. Set up monitoring alerts in Azure Monitor
4. Create a backup strategy for production deployments
