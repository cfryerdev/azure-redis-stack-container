@description('Azure region for the deployment')
param location string

@description('Base name for the deployment resources')
param deploymentName string

@description('Environment type (dev, test, prod)')
param environmentType string = 'dev'

@description('Container image to deploy')
param containerImage string = 'redis/redis-stack:latest'

@description('Redis password')
@secure()
param redisPassword string

@description('Storage account name for Redis data persistence')
param storageAccountName string

@description('Storage account key')
@secure()
param storageAccountKey string

@description('File share name for Redis data')
param fileShareName string

@description('Whether to enable Application Insights for monitoring')
param enableAppInsights bool = false

@description('Application Insights connection string')
@secure()
param appInsightsConnectionString string = ''

@description('Subnet ID if using virtual network')
param subnetId string = ''

@description('App Service configuration settings')
param appServiceConfig object = {
  skuName: 'P1v2'
  skuTier: 'PremiumV2'
  alwaysOn: true
}

@description('Tags for the resources')
param tags object

// App Service Plan for Redis Stack
resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: '${deploymentName}-${environmentType}-plan'
  location: location
  tags: tags
  sku: {
    name: appServiceConfig.skuName
    tier: appServiceConfig.skuTier
    size: appServiceConfig.skuName
    family: contains(appServiceConfig.skuName, 'v2') ? 'Pv2' : 'P'
    capacity: contains(appServiceConfig, 'capacity') ? appServiceConfig.capacity : 1
  }
  kind: 'linux'
  properties: {
    reserved: true
    zoneRedundant: contains(appServiceConfig, 'zoneRedundant') ? appServiceConfig.zoneRedundant : false
  }
}

// App Service for Redis Stack
resource redisWebApp 'Microsoft.Web/sites@2022-03-01' = {
  name: '${deploymentName}-${environmentType}-app'
  location: location
  tags: tags
  kind: 'app,linux,container'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'DOCKER|${containerImage}'
      alwaysOn: contains(appServiceConfig, 'alwaysOn') ? appServiceConfig.alwaysOn : true
      ftpsState: 'Disabled'
      http20Enabled: true
      appSettings: concat([
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'WEBSITES_PORT'
          value: '8001'
        }
        {
          name: 'REDIS_ARGS'
          value: '--requirepass ${redisPassword}'
        }
        {
          name: 'AZURE_STORAGE_ACCOUNT'
          value: storageAccountName
        }
        {
          name: 'AZURE_STORAGE_KEY'
          value: storageAccountKey
        }
        {
          name: 'AZURE_STORAGE_SHARE'
          value: fileShareName
        }
      ], enableAppInsights ? [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'APP_INSIGHTS_ROLE_NAME'
          value: 'redis-stack'
        }
      ] : [])
      azureStorageAccounts: {
        redisdata: {
          type: 'AzureFiles'
          accountName: storageAccountName
          accessKey: storageAccountKey
          shareName: fileShareName
          mountPath: '/data'
        }
      }
    }
    virtualNetworkSubnetId: empty(subnetId) ? null : subnetId
    httpsOnly: true
  }
}

// Custom hostname configuration
resource redisWebAppConfig 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: redisWebApp
  name: 'web'
  properties: {
    openIdConnectClientId: null
    ipSecurityRestrictions: contains(appServiceConfig, 'ipRestrictions') ? appServiceConfig.ipRestrictions : [
      {
        ipAddress: 'Any'
        action: 'Allow'
        priority: 2147483647
        name: 'Allow all'
        description: 'Allow all access'
      }
    ]
  }
}

// Outputs
output appServiceId string = redisWebApp.id
output appServicePlanId string = appServicePlan.id
output redisEndpoint string = '${redisWebApp.properties.defaultHostName}:6379'
output redisInsightEndpoint string = 'https://${redisWebApp.properties.defaultHostName}'
