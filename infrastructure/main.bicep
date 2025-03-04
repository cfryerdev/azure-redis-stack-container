@description('Name for the deployment resources')
param deploymentName string

@description('Azure region for the deployment')
param location string = resourceGroup().location

@description('Environment type (dev, test, prod)')
@allowed([
  'dev'
  'test'
  'prod'
])
param environmentType string = 'dev'

@description('Deployment type (aci, app-service, aks)')
@allowed([
  'aci'
  'app-service'
  'aks'
])
param deploymentType string = 'aci'

@description('Password for Redis')
@secure()
param redisPassword string

@description('Storage account name for Redis data persistence')
param storageAccountName string

@description('Name of the file share for Redis data')
param fileShareName string = 'redisdata'

@description('Whether to enable Application Insights for monitoring')
param enableAppInsights bool = true

@description('Container registry name (if using private registry)')
param containerRegistryName string = ''

@description('Container image name (defaults to redis/redis-stack:latest)')
param containerImageName string = 'redis/redis-stack:latest'

@description('Number of CPU cores for the container')
param containerCpuCores int = 1

@description('Memory in GB for the container')
param containerMemoryGb int = 2

@description('DNS name label for the container')
param containerDnsNameLabel string = 'redisstack'

@description('Number of days to retain logs')
param logRetentionDays int = 30

@description('App Service specific configuration')
param appServiceConfig object = {
  skuName: 'P1v2'
  skuTier: 'PremiumV2'
  alwaysOn: true
}

@description('Azure Container Instances specific configuration')
param aciConfig object = {
  restartPolicy: 'Always'
}

@description('Enable Virtual Network integration')
param enableVirtualNetwork bool = false

@description('Address prefix for the virtual network')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Address prefix for the subnet')
param subnetAddressPrefix string = '10.0.0.0/24'

@description('Tags for the resources')
param tags object = {
  environment: environmentType
  application: 'redis-stack'
}

// Create a resource group name using the deploymentName and environmentType
var rgName = '${deploymentName}-${environmentType}-rg'

// Resource names
var appInsightsName = '${deploymentName}-${environmentType}-ai'
var logAnalyticsName = '${deploymentName}-${environmentType}-logs'
var vnetName = '${deploymentName}-${environmentType}-vnet'
var nsgName = '${deploymentName}-${environmentType}-nsg'
var aciName = '${deploymentName}-${environmentType}-container'

// First deploy the common resources
module commonResources './modules/common.bicep' = {
  name: 'commonResources'
  params: {
    location: location
    storageAccountName: storageAccountName
    fileShareName: fileShareName
    logAnalyticsName: logAnalyticsName
    appInsightsName: enableAppInsights ? appInsightsName : ''
    logRetentionDays: logRetentionDays
    tags: tags
  }
}

// Deploy network resources if required
module networkResources './modules/network.bicep' = if (enableVirtualNetwork) {
  name: 'networkResources'
  params: {
    location: location
    vnetName: vnetName
    nsgName: nsgName
    vnetAddressPrefix: vnetAddressPrefix
    subnetAddressPrefix: subnetAddressPrefix
    tags: tags
  }
}

// Now deploy the container resources based on deployment type
module aciDeployment './modules/aci.bicep' = if (deploymentType == 'aci') {
  name: 'aciDeployment'
  params: {
    location: location
    containerName: aciName
    containerImage: containerImageName
    cpuCores: containerCpuCores
    memoryInGb: containerMemoryGb
    dnsNameLabel: containerDnsNameLabel
    redisPassword: redisPassword
    storageAccountName: commonResources.outputs.storageAccountName
    storageAccountKey: commonResources.outputs.storageAccountKey
    fileShareName: fileShareName
    enableApplicationInsights: enableAppInsights
    applicationInsightsConnectionString: enableAppInsights ? commonResources.outputs.appInsightsConnectionString : ''
    subnetId: enableVirtualNetwork ? networkResources.outputs.subnetId : ''
    aciConfig: aciConfig
    tags: tags
  }
}

module appServiceDeployment './modules/app-service.bicep' = if (deploymentType == 'app-service') {
  name: 'appServiceDeployment'
  params: {
    location: location
    deploymentName: deploymentName
    environmentType: environmentType
    containerImage: containerImageName
    redisPassword: redisPassword
    storageAccountName: commonResources.outputs.storageAccountName
    storageAccountKey: commonResources.outputs.storageAccountKey
    fileShareName: fileShareName
    enableAppInsights: enableAppInsights
    appInsightsConnectionString: enableAppInsights ? commonResources.outputs.appInsightsConnectionString : ''
    subnetId: enableVirtualNetwork ? networkResources.outputs.subnetId : ''
    appServiceConfig: appServiceConfig
    tags: tags
  }
}

module aksDeployment './modules/aks.bicep' = if (deploymentType == 'aks') {
  name: 'aksDeployment'
  params: {
    location: location
    deploymentName: deploymentName
    environmentType: environmentType
    containerImage: containerImageName
    containerRegistryName: containerRegistryName
    enableAppInsights: enableAppInsights
    appInsightsConnectionString: enableAppInsights ? commonResources.outputs.appInsightsConnectionString : ''
    vnetName: enableVirtualNetwork ? vnetName : ''
    subnetId: enableVirtualNetwork ? networkResources.outputs.subnetId : ''
    tags: tags
  }
}

// Output important information based on deployment type
output redisEndpoint string = deploymentType == 'aci' ? aciDeployment.outputs.redisEndpoint : 
                            deploymentType == 'app-service' ? appServiceDeployment.outputs.redisEndpoint : 
                            aksDeployment.outputs.redisEndpoint

output redisInsightEndpoint string = deploymentType == 'aci' ? aciDeployment.outputs.redisInsightEndpoint : 
                                    deploymentType == 'app-service' ? appServiceDeployment.outputs.redisInsightEndpoint : 
                                    aksDeployment.outputs.redisInsightEndpoint

output appInsightsConnectionString string = enableAppInsights ? commonResources.outputs.appInsightsConnectionString : ''
