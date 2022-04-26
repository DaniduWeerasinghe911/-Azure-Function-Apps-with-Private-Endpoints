@description('Name of the Application Insight')
param name string

@description('Location for resources to be created')
param location string = resourceGroup().location

@description('ResourceId of Log Analytics to associate App Insights to.')
param WorkspaceResourceId string

@description('Enable to allow IP collection and storage.')
param DisableIpMasking bool = false

@description('Object containing resource tags.')
param tags object = {}

@description('Enable a Can Not Delete Resource Lock. Useful for production workloads.')
param enableResourceLock bool = false

// Resource Definition
resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: name
  location: location
  tags: !empty(tags) ? tags : null
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: WorkspaceResourceId
    DisableIpMasking: DisableIpMasking
  }
}

// Resource Lock
resource deleteLock 'Microsoft.Authorization/locks@2016-09-01' = if (enableResourceLock) {
  name: '${name}-delete-lock'
  scope: appInsights
  properties: {
    level: 'CanNotDelete'
    notes: 'Enabled as part of IaC Deployment'
  }
}

// Output Resource Name and Resource Id as a standard to allow module referencing.
output name string = appInsights.name
output id string = appInsights.id
