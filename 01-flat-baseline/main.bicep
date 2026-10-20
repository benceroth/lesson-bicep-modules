// The "before": one flat file, no modules. Deploys one environment per run.
// Everything the module will own (policy) and everything the caller chooses
// (environment, SKU) is mixed together in the same place.

@allowed([
  'dev'
  'test'
  'prod'
])
param environment string

var skuName = environment == 'prod' ? 'Standard_ZRS' : 'Standard_LRS'
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
output storageAccountName string = storage.name
