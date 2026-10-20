// A caller written against storage v1.0.0. It keeps working as long as it stays pinned to v1.

module storage './storage-v1.bicep' = {
  name: 'northstar-storage-dev'
  params: {
    environment: 'dev'
    skuName: 'Standard_LRS'
  }
}

output storageAccountName string = storage.outputs.storageAccountName
