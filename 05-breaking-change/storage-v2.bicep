// storage v2.0.0 - BREAKING vs v1.0.0:
//   - new REQUIRED parameter `costCenter`
//   - output `storageAccountName` renamed to `name`
// Contract: 3 inputs (environment, skuName, costCenter), 2 outputs (storageAccountId, name).

@allowed([
  'dev'
  'test'
  'prod'
])
param environment string

@allowed([
  'Standard_LRS'
  'Standard_ZRS'
])
param skuName string

@description('Cost center billed for this storage account. Required since 2.0.0.')
param costCenter string

var storageAccountName = 'st${environment}${uniqueString(resourceGroup().id)}'

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: 'westeurope'
  sku: {
    name: skuName
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
  tags: {
    application: 'notes'
    owner: 'platform-team'
    environment: environment
    costCenter: costCenter
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 30
    }
  }
}

output storageAccountId string = storage.id
output name string = storage.name
