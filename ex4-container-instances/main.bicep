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

@description('Azure Files share quota (GB), mounted read-write on both containers')
param fileShareQuotaGb int = 5

var containerGroupName = '${namePrefix}-aci'
var dnsNameLabel = toLower('${namePrefix}-aci-${uniqueString(resourceGroup().id)}')
// Storage account names are 3-24 lowercase alphanumeric chars only — can't
// reuse namePrefix directly (hyphens, too long), so a short fixed prefix +
// uniqueString keeps this globally unique without exceeding the limit.
var storageAccountName = toLower('staciex4${uniqueString(resourceGroup().id)}')
var fileShareName = 'shared-data'
var volumeName = 'shared-data'
var volumeMountPath = '/mnt/shared'

// See README — used to scope destruction to this template's resources only.
var resourceTags = {
  managed_by: 'bicep'
  tp: 'az104-compute'
  exercise: 'ex4-container-instances'
}

// Azure Files share, mounted on both containers below to illustrate a
// container group sharing storage as well as its network lifecycle.
resource storage 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: storageAccountName
  location: location
  tags: resourceTags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2025-01-01' = {
  name: '${storage.name}/default/${fileShareName}'
  properties: {
    shareQuota: fileShareQuotaGb
  }
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
          environmentVariables: [
            {
              name: 'DEMO_ENV'
              value: 'az104-tp'
            }
            {
              name: 'DEPLOYED_BY'
              value: 'bicep'
            }
          ]
          volumeMounts: [
            {
              name: volumeName
              mountPath: volumeMountPath
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
        // and one Azure Files volume with the main container (no port exposed).
        name: 'sidecar-logger'
        properties: {
          image: 'mcr.microsoft.com/azure-cli:latest'
          command: [
            '/bin/sh'
            '-c'
            'while true; do echo "[sidecar] $(date) - still alive next to web" | tee -a ${volumeMountPath}/sidecar.log; sleep 30; done'
          ]
          volumeMounts: [
            {
              name: volumeName
              mountPath: volumeMountPath
            }
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
    volumes: [
      {
        name: volumeName
        azureFile: {
          shareName: fileShareName
          storageAccountName: storage.name
          storageAccountKey: storage.listKeys().keys[0].value
        }
      }
    ]
  }
  dependsOn: [
    fileShare
  ]
}

output containerGroupFqdn string = containerGroup.properties.ipAddress.fqdn
output containerGroupIp string = containerGroup.properties.ipAddress.ip
output logsCommand string = 'az container logs --resource-group <RG> --name ${containerGroup.name} --container-name sidecar-logger'
