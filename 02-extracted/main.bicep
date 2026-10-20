// main.bicep - orchestration for one environment (one resource group per run).

@allowed([
  'dev'
  'test'
  'prod'
])
param environment string

// Production uses zone redundancy; dev and test use local redundancy.
var skuName = environment == 'prod' ? 'Standard_ZRS' : 'Standard_LRS'

module storage './modules/storage.bicep' = {
  name: 'northstar-storage-${environment}'
  params: {
    environment: environment
    skuName: skuName
  }
}

output storageAccountId string = storage.outputs.storageAccountId
output storageAccountName string = storage.outputs.storageAccountName
