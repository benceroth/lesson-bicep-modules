// BROKEN ON PURPOSE: same parent as 02-extracted, but it uses a module whose retention drifted to 31 days.

@allowed([
  'dev'
  'test'
  'prod'
])
param environment string

var skuName = environment == 'prod' ? 'Standard_ZRS' : 'Standard_LRS'

module storage './storage.bicep' = {
  name: 'northstar-storage-${environment}'
  params: {
    environment: environment
    skuName: skuName
  }
}

output storageAccountId string = storage.outputs.storageAccountId
output storageAccountName string = storage.outputs.storageAccountName
