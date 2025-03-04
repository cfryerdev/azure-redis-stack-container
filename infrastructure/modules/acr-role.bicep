@description('The principal ID assigned to the AKS cluster')
param aksServicePrincipalId string

@description('The name of the ACR registry')
param acrName string

// Get reference to the ACR
resource acr 'Microsoft.ContainerRegistry/registries@2022-12-01' existing = {
  name: acrName
}

// Role definition for AcrPull
resource acrPullRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull role ID
}

// Assign the AcrPull role to the AKS managed identity
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, aksServicePrincipalId, acrPullRole.id)
  properties: {
    roleDefinitionId: acrPullRole.id
    principalId: aksServicePrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Output the role assignment ID
output roleAssignmentId string = roleAssignment.id
