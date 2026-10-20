// storage v1.0.0 (identical to 02-extracted/modules/storage.bicep)
// Policy-compliant application storage for Northstar Notes.
// Contract: 2 inputs (environment, skuName), 2 outputs (storageAccountId, storageAccountName).

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

var storageAccountName = 'st${environment}${uniqueString(resourceGroup().id)}'

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: 'westeurope'
  sku: {
    name: skuName
  }
  kind: 'StorageV2'
  properties: {
    // These controls are policy, not caller preferences.
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
  tags: {
    application: 'notes'
    owner: 'platform-team'
    environment: environment
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      // Every environment keeps deleted blobs for exactly 30 days.
      days: 30
    }
  }
}

// Expose only values that callers are expected to consume.
output storageAccountId string = storage.id
output storageAccountName string = storage.name
