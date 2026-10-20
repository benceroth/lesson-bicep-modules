// The same caller after migrating to storage v2.0.0 (see MIGRATION.md).

module storage './storage-v2.bicep' = {
  name: 'northstar-storage-dev'
  params: {
    environment: 'dev'
    skuName: 'Standard_LRS'
    costCenter: 'cc-1234'
  }
}

output storageAccountName string = storage.outputs.name
