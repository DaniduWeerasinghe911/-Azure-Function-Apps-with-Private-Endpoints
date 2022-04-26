// Deploys set of Private DNS Zones that map to the ones used by Private Link services

@description('Array of Private DNS Zones to create')
param dnsZoneList array = [
  'privatelink.blob.core.windows.net'
  'privatelink.table.core.windows.net'
  'privatelink.queue.core.windows.net'
  'privatelink.file.core.windows.net'
]

// Resource Definition
resource dnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [for dnsZone in dnsZoneList: {
  name: dnsZone
  location: 'global'
  properties: {}
}]
