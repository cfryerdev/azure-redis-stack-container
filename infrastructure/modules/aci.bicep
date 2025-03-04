@description('Azure region for the deployment')
param location string

@description('Name for the container instance')
param containerName string

@description('Container image to deploy')
param containerImage string = 'redis/redis-stack:latest'

@description('Number of CPU cores')
param cpuCores int = 1

@description('Memory in GB')
param memoryInGb int = 2

@description('DNS name label')
param dnsNameLabel string = 'redisstack'

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
param enableApplicationInsights bool = false

@description('Application Insights connection string')
@secure()
param applicationInsightsConnectionString string = ''

@description('Subnet ID if using virtual network')
param subnetId string = ''

@description('ACI-specific configuration settings')
param aciConfig object = {
  restartPolicy: 'Always'
}

@description('Tags for the resources')
param tags object

// Container group for Redis Stack
resource redisContainer 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: containerName
  location: location
  tags: tags
  properties: {
    containers: concat([
      {
        name: 'redis-stack'
        properties: {
          image: containerImage
          ports: [
            {
              port: 6379
              protocol: 'TCP'
            }
            {
              port: 8001
              protocol: 'TCP'
            }
          ]
          environmentVariables: [
            {
              name: 'REDIS_ARGS'
              value: '--requirepass ${redisPassword}'
            }
          ]
          resources: {
            requests: {
              memoryInGB: memoryInGb
              cpu: cpuCores
            }
          }
          volumeMounts: [
            {
              name: 'redis-data'
              mountPath: '/data'
              readOnly: false
            }
            {
              name: 'redis-logs'
              mountPath: '/var/log/redis'
              readOnly: false
            }
          ]
          command: [
            'redis-stack-server',
            '/redis-stack.conf'
          ]
        }
      }
    ], enableApplicationInsights ? [
      {
        name: 'app-insights-sidecar'
        properties: {
          image: contains(aciConfig, 'monitoringImage') ? aciConfig.monitoringImage : 'mcr.microsoft.com/azure-monitor/applicationinsights/python:latest'
          environmentVariables: [
            {
              name: 'REDIS_LOG_PATH'
              value: '/var/log/redis/redis.log'
            }
            {
              name: 'APP_INSIGHTS_CONNECTION_STRING'
              value: applicationInsightsConnectionString
            }
            {
              name: 'APP_INSIGHTS_ROLE_NAME'
              value: 'redis-stack'
            }
            {
              name: 'APP_INSIGHTS_ROLE_INSTANCE'
              value: containerName
            }
            {
              name: 'LOG_LEVEL'
              value: 'info'
            }
            {
              name: 'SAMPLING_PERCENTAGE'
              value: '100'
            }
          ]
          resources: {
            requests: {
              memoryInGB: contains(aciConfig, 'sidecarMemory') ? aciConfig.sidecarMemory : 0.5
              cpu: contains(aciConfig, 'sidecarCpu') ? aciConfig.sidecarCpu : 0.5
            }
          }
          volumeMounts: [
            {
              name: 'redis-logs'
              mountPath: '/var/log/redis'
              readOnly: true
            }
          ]
        }
      }
    ] : [])
    osType: 'Linux'
    restartPolicy: contains(aciConfig, 'restartPolicy') ? aciConfig.restartPolicy : 'Always'
    ipAddress: {
      type: empty(subnetId) ? 'Public' : 'Private'
      ports: [
        {
          port: 6379
          protocol: 'TCP'
        }
        {
          port: 8001
          protocol: 'TCP'
        }
      ]
      dnsNameLabel: empty(subnetId) ? dnsNameLabel : null
    }
    volumes: [
      {
        name: 'redis-data'
        azureFile: {
          shareName: fileShareName
          storageAccountName: storageAccountName
          storageAccountKey: storageAccountKey
        }
      }
      {
        name: 'redis-logs'
        emptyDir: {}
      }
    ]
    subnetIds: empty(subnetId) ? null : [
      {
        id: subnetId
      }
    ]
  }
}

// Calculate endpoints based on whether we're using public or private IP
var domain = empty(subnetId) ? '.${location}.azurecontainer.io' : ''
var fqdn = empty(subnetId) ? redisContainer.properties.ipAddress.fqdn : redisContainer.properties.ipAddress.ip
var redisPort = '6379'
var redisInsightPort = '8001'

// Outputs
output containerGroupId string = redisContainer.id
output containerId string = '${redisContainer.id}/containers/redis-stack'
output redisEndpoint string = '${fqdn}:${redisPort}'
output redisInsightEndpoint string = '${fqdn}:${redisInsightPort}'
output ipAddress string = redisContainer.properties.ipAddress.ip
