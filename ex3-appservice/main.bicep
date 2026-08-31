// AZ-104 Compute - Exercise 3
// App Service Plan (Linux, Standard) + containerized Web App + staging slot

@description('Prefix used to name every resource')
param namePrefix string = 'simplon-tp104'

@description('Deployment region')
param location string = resourceGroup().location

@description('App Service Plan SKU (S1 minimum required for deployment slots)')
param planSku string = 'S1'

@description('Container image (production) - official App Service Linux demo image')
param productionImage string = 'DOCKER|mcr.microsoft.com/appsvc/staticsite:latest'

@description('Container image (staging slot) - same image, illustrates a slot swap')
param stagingImage string = 'DOCKER|mcr.microsoft.com/appsvc/staticsite:latest'

@description('Minimum plan instance count allowed by autoscale')
param planMinCapacity int = 1

@description('Maximum plan instance count allowed by autoscale')
param planMaxCapacity int = 3

// Web App names must be globally unique (they form the azurewebsites.net subdomain).
var webAppName = toLower('${namePrefix}-web-${uniqueString(resourceGroup().id)}')
var planName = '${namePrefix}-plan'

// See README — used to scope destruction to this template's resources only.
var resourceTags = {
  managed_by: 'bicep'
  tp: 'az104-compute'
  exercise: 'ex3-appservice'
}

resource plan 'Microsoft.Web/serverfarms@2025-03-01' = {
  name: planName
  location: location
  tags: resourceTags
  sku: {
    name: planSku
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource webApp 'Microsoft.Web/sites@2025-03-01' = {
  name: webAppName
  location: location
  tags: resourceTags
  kind: 'app,linux,container'
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: productionImage
      alwaysOn: true
      appSettings: [
        {
          name: 'ENVIRONMENT_NAME'
          value: 'production'
        }
      ]
    }
  }
}

// staging slot: same plan, lets a new version be deployed and then swapped in.
resource stagingSlot 'Microsoft.Web/sites/slots@2025-03-01' = {
  parent: webApp
  name: 'staging'
  location: location
  tags: resourceTags
  kind: 'app,linux,container'
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: stagingImage
      alwaysOn: true
      appSettings: [
        {
          name: 'ENVIRONMENT_NAME'
          value: 'staging'
        }
      ]
    }
  }
}

// Autoscale on the plan itself (not the VM/VMSS layer): CPU-based, in the
// spirit of the exercise 2 autoscale but for the App Service Plan metric.
resource planAutoscale 'Microsoft.Insights/autoscalesettings@2022-10-01' = {
  name: '${planName}-autoscale'
  location: location
  tags: resourceTags
  properties: {
    enabled: true
    targetResourceUri: plan.id
    profiles: [
      {
        name: 'profil-cpu'
        capacity: {
          minimum: string(planMinCapacity)
          maximum: string(planMaxCapacity)
          default: string(planMinCapacity)
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricResourceUri: plan.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 70
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricResourceUri: plan.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: 30
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
        ]
      }
    ]
  }
}

output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output stagingSlotUrl string = 'https://${stagingSlot.properties.defaultHostName}'
output swapCommand string = 'az webapp deployment slot swap --resource-group <RG> --name ${webApp.name} --slot staging --target-slot production'
