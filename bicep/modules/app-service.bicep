// ──────────────────────────────────────────────────────────────────────────────
// app-service.bicep — Python App Service, uses the shared plan (existing resource
// resolved in main.bicep). Mirror of the "app-service" Terraform module and
// step [2] of provision.sh
// ──────────────────────────────────────────────────────────────────────────────

@description('Learner identifier used for resource naming (firstname-lastname)')
param owner string

@description('Resource ID of the shared App Service plan (pre-created by the trainer, never managed here)')
param servicePlanId string

@description('Tags to apply to all resources in this module')
param tags object

var appName = 'app-${owner}-bcp'

// Resolve the shared plan's own location from inside this module rather than
// receiving it as a parameter computed from an `existing` resource in the parent
// template (e.g. `sharedPlan.location`) — passing that kind of runtime-evaluated
// value across a module boundary causes `az deployment group what-if` to
// short-circuit validation of this nested deployment (NestedDeploymentShortCircuited,
// see https://aka.ms/WhatIfEvalStopped). Mirrors the `data.azurerm_service_plan.plan`
// lookup in the Terraform module, which does the same split-and-fetch locally.
resource plan 'Microsoft.Web/serverFarms@2024-11-01' existing = {
  name: split(servicePlanId, '/')[8]
  scope: resourceGroup(split(servicePlanId, '/')[4])
}

resource app 'Microsoft.Web/sites@2024-11-01' = {
  name: appName
  location: plan.location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: servicePlanId
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      http20Enabled: true
      ftpsState: 'Disabled' // no FTP(S) deployment — SCM/zip-deploy only
      healthCheckPath: '/health'
      linuxFxVersion: 'PYTHON|3.11'
      appSettings: [
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'ENVIRONMENT'
          value: 'tp'
        }
        {
          name: 'WEBSITE_HEALTHCHECK_MAXPINGFAILURES'
          value: '5'
        }
      ]
    }
  }
}

// Detailed diagnostic logging — mirror of the "logs" block in the Terraform resource
resource appLogs 'Microsoft.Web/sites/config@2024-11-01' = {
  parent: app
  name: 'logs'
  properties: {
    detailedErrorMessages: {
      enabled: true
    }
    failedRequestsTracing: {
      enabled: true
    }
    httpLogs: {
      fileSystem: {
        enabled: true
        retentionInDays: 7
        retentionInMb: 35
      }
    }
  }
}

@description('Default hostname of the App Service')
output defaultHostname string = app.properties.defaultHostName
