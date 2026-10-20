// BROKEN ON PURPOSE: a caller of the leaky module weakens TLS. This compiles.

module storage './storage.bicep' = {
  name: 'northstar-storage-prod'
  params: {
    environment: 'prod'
    skuName: 'Standard_ZRS'
    minimumTlsVersion: 'TLS1_0'
  }
}
