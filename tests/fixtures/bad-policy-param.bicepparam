using '../../02-extracted/modules/storage.bicep'

param environment = 'prod'
param skuName = 'Standard_ZRS'
// Policy is not a parameter: passing it must be rejected.
param minimumTlsVersion = 'TLS1_0'
