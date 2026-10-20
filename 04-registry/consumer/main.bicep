// Consumes the shared storage module from a private registry, pinned to an exact version.
// Requires the module to have been published first (see ../publish.ps1) and the alias in
// ../bicepconfig.json to point at your own registry. Not built by offline CI.

@allowed([
  'dev'
  'test'
  'prod'
])
param environment string

var skuName = environment == 'prod' ? 'Standard_ZRS' : 'Standard_LRS'

module storage 'br/northstar:storage:1.0.0' = {
  name: 'northstar-storage-${environment}'
  params: {
    environment: environment
    skuName: skuName
  }
}

output storageAccountId string = storage.outputs.storageAccountId
output storageAccountName string = storage.outputs.storageAccountName
