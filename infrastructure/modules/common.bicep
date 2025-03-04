@description('Azure region for the deployment')
param location string

@description('Storage account name for Redis data persistence')
param storageAccountName string

@description('Name of the file share for Redis data')
param fileShareName string

@description('Name of the Log Analytics workspace')
param logAnalyticsName string

@description('Name of the Application Insights instance')
param appInsightsName string = ''

@description('Number of days to retain logs')
param logRetentionDays int = 30

@description('Tags for the resources')
param tags object

// Storage Account for Redis data persistence
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
}

// File Share for Redis data
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-09-01' = {
  name: '${storageAccount.name}/default/${fileShareName}'
  properties: {
    shareQuota: 100
    enabledProtocols: 'SMB'
  }
}

// Log Analytics workspace for logs and Application Insights
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: logRetentionDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: -1
    }
  }
}

// Application Insights for monitoring
resource appInsights 'Microsoft.Insights/components@2020-02-02' = if (!empty(appInsightsName)) {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    RetentionInDays: logRetentionDays
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Outputs
output storageAccountName string = storageAccount.name
output storageAccountKey string = listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value
output fileShareName string = fileShareName
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output appInsightsConnectionString string = !empty(appInsightsName) ? appInsights.properties.ConnectionString : ''
output appInsightsInstrumentationKey string = !empty(appInsightsName) ? appInsights.properties.InstrumentationKey : ''
