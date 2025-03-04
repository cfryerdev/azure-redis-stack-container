@description('Azure region for the deployment')
param location string

@description('Name for the virtual network')
param vnetName string

@description('Name for the network security group')
param nsgName string

@description('Address prefix for the virtual network')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Address prefix for the subnet')
param subnetAddressPrefix string = '10.0.0.0/24'

@description('Tags for the resources')
param tags object

// Network Security Group with rules for Redis
resource nsg 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowRedis'
        properties: {
          description: 'Allow Redis traffic'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '6379'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowRedisInsight'
        properties: {
          description: 'Allow RedisInsight traffic'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '8001'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: subnetAddressPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

// Outputs
output vnetId string = vnet.id
output subnetId string = '${vnet.id}/subnets/default'
output nsgId string = nsg.id
