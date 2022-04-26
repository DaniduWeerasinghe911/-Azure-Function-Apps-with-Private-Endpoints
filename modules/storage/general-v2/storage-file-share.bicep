@description('Name of the Resource for which to create the Private Endpoint')
param fileShareName string = ''

@description('Name of the Resource for which to create the Private Endpoint')
param storageAccountName string = ''

@description('Share Quota')
param shareQuota int = 1024

@description('Enabled Protocols')
@allowed([
  'NFS'
  'SMB'
  'null'
])
param enabledProtocols string = 'SMB'

@description('Access Tier Details')
@allowed([
  'Cool'
  'Hot'
  'Premium'
  'TransactionOptimized'
])
param accessTier string = 'Premium'

var fileShare = '${storageAccountName}/default/${fileShareName}'

resource storage_fileshare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-08-01' = {
  name: fileShare
  properties: {
    accessTier: accessTier
    enabledProtocols: enabledProtocols
    metadata: {}
    shareQuota: shareQuota
  }
}

