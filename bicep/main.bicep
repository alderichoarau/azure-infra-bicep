// ──────────────────────────────────────────────────────────────────────────────
// main.bicep — Azure resources provisioned with Bicep
//
// Mirror of azure-infra-cli/bash/provision.sh and azure-infra-terraform/terraform:
//   - Storage Account + Blob containers (api-logs private / api-config public)
//   - Python App Service (shared plan)
//   - Python Function App + dedicated storage (shared plan)
//   - Static Web App
//   - Azure Container Instance (ACI — nginx)
//   - Network: VNet + subnets + NSGs
//
// Deployed directly into the Resource Group pre-created by the trainer
// (`az deployment group create --resource-group rg-<owner> ...`) — the Resource
// Group and the shared App Service plan are never managed by this template.
// ──────────────────────────────────────────────────────────────────────────────

targetScope = 'resourceGroup'

@description('Learner identifier (firstname-lastname, lowercase, hyphens). Ex: john-doe')
@minLength(3)
@maxLength(40)
param owner string

@description('Azure region for resources owned by this template')
param location string = 'francecentral'

@description('Resource Group hosting the shared App Service plan (pre-created by the trainer)')
param sharedResourceGroupName string = 'rg-shared-prf2026'

@description('Name of the shared App Service plan (pre-created by the trainer)')
param sharedPlanName string = 'plan-npr-prf2026'

@description('Azure region for the Static Web App — not available in francecentral')
param staticWebAppLocation string = 'westeurope'

@description('Additional tags to merge with the default tags')
param tags object = {}

// NOTE: unlike Terraform's `can(regex(...))` variable validation, Bicep parameter
// decorators do not currently support regex constraints — only length checks and
// @allowed enum lists. `toLower()`/`replace()` below normalize the value defensively;
// enforce the naming convention upstream (PR review / Azure Policy) if needed.
var defaultTags = union(
  {
    managed_by: 'bicep'
    environment: 'tp'
    owner: owner
  },
  tags
)

// ── Existing resources (pre-created by the trainer, never managed here) ───────

// Shared App Service plan — lives in a separate Resource Group
resource sharedPlan 'Microsoft.Web/serverFarms@2024-11-01' existing = {
  name: sharedPlanName
  scope: resourceGroup(sharedResourceGroupName)
}

// ── Storage ───────────────────────────────────────────────────────────────────

module storage 'modules/storage.bicep' = {
  name: 'deploy-storage'
  params: {
    owner: owner
    location: location
    tags: defaultTags
  }
}

// ── App Service ───────────────────────────────────────────────────────────────

module appService 'modules/app-service.bicep' = {
  name: 'deploy-app-service'
  params: {
    owner: owner
    servicePlanId: sharedPlan.id
    tags: defaultTags
  }
}

// ── Function App ──────────────────────────────────────────────────────────────

module functionApp 'modules/function-app.bicep' = {
  name: 'deploy-function-app'
  params: {
    owner: owner
    location: location
    servicePlanId: sharedPlan.id
    tags: defaultTags
  }
}

// ── Static Web App ────────────────────────────────────────────────────────────
// Kept inline (single resource, no child resources) — mirrors main.tf structure.
// Static Web Apps are not available in francecentral, hence the dedicated parameter.

resource staticWebApp 'Microsoft.Web/staticSites@2024-11-01' = {
  name: 'stapp-${owner}-bcp'
  location: staticWebAppLocation
  tags: defaultTags
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  properties: {
    provider: 'None'
  }
}

// ── Container Instance ────────────────────────────────────────────────────────

module container 'modules/container.bicep' = {
  name: 'deploy-container'
  params: {
    owner: owner
    location: location
    tags: defaultTags
  }
}

// ── Network ───────────────────────────────────────────────────────────────────

module network 'modules/network.bicep' = {
  name: 'deploy-network'
  params: {
    owner: owner
    location: location
    tags: defaultTags
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────

@description('Name of the business Storage Account')
output storageAccountName string = storage.outputs.storageAccountName

@description('URL of the private api-logs container')
output blobContainerPrivateUrl string = storage.outputs.containerPrivateUrl

@description('Public URL of the api-config container')
output blobContainerPublicUrl string = storage.outputs.containerPublicUrl

@description('URL of the App Service')
output appServiceUrl string = 'https://${appService.outputs.defaultHostname}'

@description('URL of the Function App')
output functionAppUrl string = 'https://${functionApp.outputs.defaultHostname}'

@description('URL of the Static Web App')
output staticWebAppUrl string = 'https://${staticWebApp.properties.defaultHostname}'

@description('FQDN of the Container Instance')
output containerFqdn string = 'http://${container.outputs.fqdn}'

@description('Name of the VNet')
output vnetName string = network.outputs.vnetName

@description('Name of the NSG attached to subnet-frontend')
output nsgName string = network.outputs.nsgFrontendName
