// A caller that is "allowed" by the parts-bin module and still violates Northstar policy.
// This compiles cleanly: nothing in the module's contract stops it.

module weak './modules/storage-everything.bicep' = {
  name: 'northstar-storage-weak'
  params: {
    name: 'stweak${uniqueString(resourceGroup().id)}'
    skuName: 'Premium_LRS'
    supportsHttpsTrafficOnly: false
    minimumTlsVersion: 'TLS1_0'
    allowBlobPublicAccess: true
    deleteRetentionEnabled: false
    deleteRetentionDays: 1
    // No tags at all: no owner, no application, no environment.
  }
}

output storageAccountId string = weak.outputs.id
