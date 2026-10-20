// Shows what an *un-migrated* caller looks like against v2. This file is EXPECTED NOT TO COMPILE;
// tests/contract-tests.ps1 asserts that. It lives in tests/fixtures so the main build stays green.

module storage '../../05-breaking-change/storage-v2.bicep' = {
  name: 'northstar-storage-dev'
  params: {
    environment: 'dev'
    skuName: 'Standard_LRS'
  }
}

output storageAccountName string = storage.outputs.storageAccountName
