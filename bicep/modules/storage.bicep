// ──────────────────────────────────────────────────────────────────────────────
// storage.bicep — Business Storage Account + Blob containers (private/public)
// Mirror of the "storage" Terraform module and step [1]/[6] of provision.sh
// ──────────────────────────────────────────────────────────────────────────────

@description('Learner identifier used for resource naming (firstname-lastname)')
param owner string

@description('Azure region for the storage account')
param location string

@description('Tags to apply to all resources in this module')
param tags object

// Azure constraint: storage account names are 3-24 chars, lowercase letters/digits only,
// globally unique across all of Azure — hence the "bcp" suffix (Bicep) to avoid collisions
// with the "cli" / "tf" variants of this TP deployed in the same subscription.
var storageAccountName = 'st${toLower(replace(owner, '-', ''))}bcp'

resource sa 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowSharedKeyAccess: false // Azure AD / RBAC only — no shared key auth
    // TP: exception volontaire — api-config est un conteneur public de config statique.
    // Cf. ps-rule.yaml (règle Azure.Storage.PublicAccess suppimée pour st*bcp)
    allowBlobPublicAccess: true
    networkAcls: {
      defaultAction: 'Allow' // TP: accès réseau ouvert — pas de Private Endpoint (hors périmètre TP)
    }
  }
}

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2025-01-01' = {
  parent: sa
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// Private container — API logs (authenticated access only)
resource apiLogsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-01-01' = {
  parent: blobServices
  name: 'api-logs'
  properties: {
    publicAccess: 'None'
  }
}

// Public container — API configuration (anonymous blob read access, intentional)
resource apiConfigContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-01-01' = {
  parent: blobServices
  name: 'api-config'
  properties: {
    publicAccess: 'Blob'
  }
}

@description('Name of the business Storage Account')
output storageAccountName string = sa.name

@description('Resource ID of the business Storage Account')
output storageAccountId string = sa.id

@description('URL of the private api-logs container')
output containerPrivateUrl string = '${sa.properties.primaryEndpoints.blob}${apiLogsContainer.name}'

@description('Public URL of the api-config container')
output containerPublicUrl string = '${sa.properties.primaryEndpoints.blob}${apiConfigContainer.name}'
