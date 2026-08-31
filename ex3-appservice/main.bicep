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
    }
  }
}

output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output stagingSlotUrl string = 'https://${stagingSlot.properties.defaultHostName}'
output swapCommand string = 'az webapp deployment slot swap --resource-group <RG> --name ${webApp.name} --slot staging --target-slot production'
