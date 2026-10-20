// modules/storage-everything.bicep
// ANTI-PATTERN: a "parts bin". Every resource property is a parameter, so
// every caller re-decides policy. Kept here only as a counterexample.

param name string
param location string = resourceGroup().location
param skuName string = 'Standard_LRS'
param kind string = 'StorageV2'
param accessTier string = 'Hot'
param supportsHttpsTrafficOnly bool = true
param minimumTlsVersion string = 'TLS1_2'
param allowBlobPublicAccess bool = false
param allowSharedKeyAccess bool = true
param publicNetworkAccess string = 'Enabled'
param defaultToOAuthAuthentication bool = false
param deleteRetentionEnabled bool = true
param deleteRetentionDays int = 30
param containerDeleteRetentionEnabled bool = false
param containerDeleteRetentionDays int = 7
param versioningEnabled bool = false
param networkAclsDefaultAction string = 'Allow'
param tags object = {}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: location
  sku: {
    name: skuName
  }
  kind: kind
  tags: tags
  properties: {
    accessTier: accessTier
    supportsHttpsTrafficOnly: supportsHttpsTrafficOnly
    minimumTlsVersion: minimumTlsVersion
    allowBlobPublicAccess: allowBlobPublicAccess
    allowSharedKeyAccess: allowSharedKeyAccess
    publicNetworkAccess: publicNetworkAccess
    defaultToOAuthAuthentication: defaultToOAuthAuthentication
    networkAcls: {
      defaultAction: networkAclsDefaultAction
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: deleteRetentionEnabled
      days: deleteRetentionDays
    }
    containerDeleteRetentionPolicy: {
      enabled: containerDeleteRetentionEnabled
      days: containerDeleteRetentionDays
    }
    isVersioningEnabled: versioningEnabled
  }
}

// Mirrors properties "just in case": each one is now a dependency.
output id string = storage.id
output name string = storage.name
output location string = storage.location
output skuName string = storage.sku.name
output kind string = storage.kind
output primaryBlobEndpoint string = storage.properties.primaryEndpoints.blob
output provisioningState string = storage.properties.provisioningState
