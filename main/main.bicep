targetScope = 'subscription'

@description('Resource Group Name')
param platformRgName string = 'azure-function-rg'

@description('Virtual Network Name')
param vnetName string = 'functionapp-vnet'

@description('Log Analytics Workspace Name')
param workspaceName string = 'functionapp-log'

@description('App Insights Name')
param appInsightsName string = 'functionapp-appins'

@description('Function App Name')
param fnAppName string = 'functionapp-appins'

@description('Storage Account Name')
param storageAccountName string = 'st${uniqueString(subscription().subscriptionId)}'

@description('The IP adddress space used for the virtual network.')
param vnetAddressPrefix string = '10.100.0.0/16'

@description('The IP address space used for the Azure Function integration subnet.')
param applicationSubnetAddressPrefix string = '10.100.0.0/24'

@description('The IP address space used for the private endpoints.')
param privateEndpointSubnetAddressPrefix string = '10.100.1.0/24'

@description('Array of Private DNS Zones to create')
param dnsZoneList array = [
  'privatelink.blob.core.windows.net'
  'privatelink.table.core.windows.net'
  'privatelink.queue.core.windows.net'
  'privatelink.file.core.windows.net'
]

@description('Azure Region')
param location string = 'australiaeast'

@description('Specifies the Azure Function hosting plan SKU.')
@allowed([
  'EP1'
  'EP2'
  'EP3'
])
param functionAppPlanSku string = 'EP1'

@description('Enable Resource Locks')
param enableResourceLock bool = false

@description('Private Endpoint Connection Array')
param storagePEs array = [
  {
    type: 'blob'
  }
  {
    type: 'file'
  }
  {
    type: 'queue'
  }
  {
    type: 'table'
  }
]



//Define Tags to assing to the resource group
var tags = {

}

//Deploy Resource Group
// Resource Group
resource rg_shdSvcs 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: platformRgName
  tags: tags
  location: location
}

//Deploy Virtual Networks 
module virtualNetwork '../modules/networking/vnet/vnet.bicep' = {
  scope:resourceGroup(rg_shdSvcs.name)
  name: 'deploy_Virtual_Network'
  params: {
    location:location
    addressPrefixes: [
      vnetAddressPrefix
    ]
    enableResourceLock: enableResourceLock
    subnets: [
      {
        name: 'application-sn'
        networkSecurityGroup:''
        routeTable:''
        serviceEndpoints:[]
        serviceEndpointPolicies:[]
        privateEndpointNetworkPolicies: 'Enabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
        delegations: [
            {
              name: 'webapp'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
          addressPrefix: applicationSubnetAddressPrefix
        }
      {
        name: 'privateendpoint-sn'
        networkSecurityGroup:''
        routeTable:''
        serviceEndpoints:[]
        serviceEndpointPolicies:[]
        delegations:[]
        privateEndpointNetworkPolicies: 'Disabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
        addressPrefix: privateEndpointSubnetAddressPrefix
        }
    ]
    vnetName: vnetName
  }
}

//Deploy Private DNS Zones
module privateDNS '../modules/private-dns/private-link-dns-zones.bicep' = {
  scope:resourceGroup(rg_shdSvcs.name)
  name: 'deploy_Private_DNS'
  params:{
  dnsZoneList:dnsZoneList
  }
  dependsOn:[
    virtualNetwork
  ]
}

//Deploy Private DNS Zones Link
module privateDNSLink '../modules/private-dns/private-dns-vnet-link.bicep' = {
  scope: resourceGroup(rg_shdSvcs.name)
  name: 'deploy_Private_DNS_Link'
  params: {
    dnsZoneList: dnsZoneList
    linkPrefix: 'hub-'
    vnetId: virtualNetwork.outputs.id
  }
  dependsOn:[
    privateDNS
  ]
}

//Deploy Function App Storage
module storageAccount '../modules/storage/general-v2/storage.bicep' = {
  scope: resourceGroup(rg_shdSvcs.name)
  name: 'deploy_Storage_Account'
  params: {
    location:location
    storageAccountName: storageAccountName
    storageSku: 'Standard_LRS'
    networkAclsDefaultAction: 'Deny'
    fileShareName: 'functioncontentshare'
  }
  dependsOn:[
    virtualNetwork
  ]
}

//Deploy Storage Account Private Endpoints
module storageAccountPE '../modules/storage/general-v2/storage-PE.bicep' = [for storagePE in storagePEs: {
  scope: resourceGroup(rg_shdSvcs.name)
  name: 'deploy_st_pe_${storagePE.type}'
  params: {
    location:location
    dnsZoneResourceGroup: rg_shdSvcs.name
    dnsZoneSubscriptionId: subscription().subscriptionId
    id: storageAccount.outputs.id
    resourceName: storageAccountName
    subnetId: '${virtualNetwork.outputs.id}/subnets/privateendpoint-sn'
    type: storagePE.type
  }
}]

//Deploy Log Analytics Workspace
module logAnalytics '../modules/log-analytics/log-analytics.bicep' = {
  scope: resourceGroup(rg_shdSvcs.name)
  name: 'deploy_logAnalytics'
  params: {
    location:location
    workspaceName: workspaceName
  }
}

//Deploy Application Insights
module appInsights '../modules/app-insights/app-insights.bicep' = {
  scope: resourceGroup(rg_shdSvcs.name)
  name: 'deploy_appinsights'
  params: {
    location:location
    name: appInsightsName
    WorkspaceResourceId: logAnalytics.outputs.id
  }
}

//Deploy App Service Plan
module appServicePlan '../modules/web/app-service/app-service-plan-windows.bicep' = {
  scope: resourceGroup(rg_shdSvcs.name)
  name: 'deploy_appService_Plan'
  params: {
    location:location
    appPlanName: 'functionApp'
    skuName:functionAppPlanSku
  }
}

//Deploy Function App

module functionApp '../modules/web/function/function-app-vnet-integrated.bicep' = {
  scope: resourceGroup(rg_shdSvcs.name)
  name: 'deploy_Function_App'
  params: {
    location:location
    appInsightsId: appInsights.outputs.id
    fncAppName: fnAppName
    functionRuntime: 'dotnet'
    serverFarmId: appServicePlan.outputs.id
    storageAccountId: storageAccount.outputs.id
    subnetId: '${virtualNetwork.outputs.id}/subnets/application-sn'
    functionContentShareName:'functioncontentshare'
  }
  dependsOn:[
    virtualNetwork
    appServicePlan
    appInsights
    storageAccountPE
  ]
}
