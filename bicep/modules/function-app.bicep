// ──────────────────────────────────────────────────────────────────────────────
// function-app.bicep — Python Function App, dedicated storage + shared plan.
// Mirror of the "function-app" Terraform module and step [3] of provision.sh
// ──────────────────────────────────────────────────────────────────────────────

@description('Learner identifier used for resource naming (firstname-lastname)')
param owner string

@description('Azure region for the Function App and its dedicated storage account')
param location string

@description('Resource ID of the shared App Service plan (pre-created by the trainer, never managed here)')
param servicePlanId string

@description('Tags to apply to all resources in this module')
param tags object

var functionStorageAccountName = 'stfn${toLower(replace(owner, '-', ''))}bcp'
var functionAppName = 'fn-${owner}-bcp'

// Storage dedicated to the Function App (required — kept separate from business storage)
resource fnStorage 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: functionStorageAccountName
  location: location
  tags: union(tags, { purpose: 'function-storage' })
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowSharedKeyAccess: false // Azure AD / managed identity only
    allowBlobPublicAccess: false
  }
}

resource fnBlobServices 'Microsoft.Storage/storageAccounts/blobServices@2025-01-01' = {
  parent: fnStorage
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

resource fn 'Microsoft.Web/sites@2024-11-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: servicePlanId
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      linuxFxVersion: 'PYTHON|3.11'
      appSettings: [
        // Managed-identity access to the dedicated storage — no connection string / key
        {
          name: 'AzureWebJobsStorage__accountName'
          value: fnStorage.name
        }
        {
          name: 'AzureWebJobsStorage__credential'
          value: 'managedidentity'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'ENVIRONMENT'
          value: 'tp'
        }
      ]
    }
  }
  dependsOn: [
    fnBlobServices
  ]
}

// Grants the Function App's system-assigned identity access to its dedicated storage
// (Storage Blob Data Owner — built-in role ID b7e6dc6d-f1e8-4753-8033-0f276bb0955b)
resource fnStorageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(fnStorage.id, fn.id, 'StorageBlobDataOwner')
  scope: fnStorage
  properties: {
    principalId: fn.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
    )
  }
}

@description('Default hostname of the Function App')
output defaultHostname string = fn.properties.defaultHostName

@description('Name of the storage account dedicated to the Function App')
output functionStorageName string = fnStorage.name
