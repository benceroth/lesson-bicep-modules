using '../../02-extracted/modules/storage.bicep'

param environment = 'prod'
// Not an approved SKU: must be rejected at compile time.
param skuName = 'Premium_LRS'
