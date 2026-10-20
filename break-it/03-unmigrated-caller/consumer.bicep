// BROKEN ON PURPOSE: a v1-style caller pointed at storage v2.

module storage '../../05-breaking-change/storage-v2.bicep' = {
  name: 'northstar-storage-dev'
  params: {
    environment: 'dev'
    skuName: 'Standard_LRS'
  }
}

output storageAccountName string = storage.outputs.storageAccountName
