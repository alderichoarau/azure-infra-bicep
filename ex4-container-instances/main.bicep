// AZ-104 Compute - Exercise 4
// Azure Container Instances: a two-container group (web + sidecar)

@description('Prefix used to name every resource')
param namePrefix string = 'simplon-tp104'

@description('Deployment region (check ACI availability in the chosen region)')
param location string = resourceGroup().location

@description('Container group restart policy')
@allowed([
  'Always'
  'OnFailure'
  'Never'
])
param restartPolicy string = 'Always'

@description('CPU cores allocated to the web container')
param webCpu int = 1

@description('Memory (GB) allocated to the web container')
param webMemoryInGb int = 1

@description('CPU cores allocated to the sidecar container')
param sidecarCpu int = 1

@description('Memory (GB) allocated to the sidecar container')
param sidecarMemoryInGb int = 1

var containerGroupName = '${namePrefix}-aci'
var dnsNameLabel = toLower('${namePrefix}-aci-${uniqueString(resourceGroup().id)}')

// See README — used to scope destruction to this template's resources only.
var resourceTags = {
  managed_by: 'bicep'
  tp: 'az104-compute'
  exercise: 'ex4-container-instances'
}

resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2025-09-01' = {
  name: containerGroupName
  location: location
  tags: resourceTags
  properties: {
    osType: 'Linux'
    restartPolicy: restartPolicy
    ipAddress: {
      type: 'Public'
      dnsNameLabel: dnsNameLabel
      ports: [
        {
          protocol: 'Tcp'
          port: 80
        }
      ]
    }
    containers: [
      {
        // Main container: official Microsoft demo web app.
        name: 'web'
        properties: {
          image: 'mcr.microsoft.com/azuredocs/aci-helloworld:latest'
          ports: [
            {
              protocol: 'Tcp'
              port: 80
            }
          ]
          resources: {
            requests: {
              cpu: webCpu
              memoryInGB: webMemoryInGb
            }
          }
        }
      }
      {
        // Sidecar: illustrates a container group sharing one network lifecycle
        // (no port exposed).
        name: 'sidecar-logger'
        properties: {
          image: 'mcr.microsoft.com/azure-cli:latest'
          command: [
            '/bin/sh'
            '-c'
            'while true; do echo "[sidecar] $(date) - still alive next to web"; sleep 30; done'
          ]
          resources: {
            requests: {
              cpu: sidecarCpu
              memoryInGB: sidecarMemoryInGb
            }
          }
        }
      }
    ]
  }
}

output containerGroupFqdn string = containerGroup.properties.ipAddress.fqdn
output containerGroupIp string = containerGroup.properties.ipAddress.ip
output logsCommand string = 'az container logs --resource-group <RG> --name ${containerGroup.name} --container-name sidecar-logger'
