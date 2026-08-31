// Reusable VM module: public IP + NIC + Linux VM + nginx extension

@description('Naming prefix')
param namePrefix string

@description('Region')
param location string

@description('Instance index (used for unique naming: vm00, vm01, ...)')
param vmIndex int

@description('Subnet ID to attach the VM to')
param subnetId string

@description('Admin username')
param adminUsername string

@description('SSH public key')
@secure()
param adminPublicKey string

@description('VM size')
param vmSize string = 'Standard_B1s'

var suffix = padLeft(string(vmIndex), 2, '0')
var vmName = '${namePrefix}-vm${suffix}'
var pipName = '${namePrefix}-pip${suffix}'
var nicName = '${namePrefix}-nic${suffix}'

// See README — used to scope destruction to this module's resources only.
var resourceTags = {
  managed_by: 'bicep'
  tp: 'az104-compute'
  exercise: 'bonus-modules'
}

resource pip 'Microsoft.Network/publicIPAddresses@2025-07-01' = {
  name: pipName
  location: location
  tags: resourceTags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: toLower('${namePrefix}-${suffix}-${uniqueString(resourceGroup().id, suffix)}')
    }
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2025-07-01' = {
  name: nicName
  location: location
  tags: resourceTags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: pip.id
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2025-11-01' = {
  name: vmName
  location: location
  tags: resourceTags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: adminPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

resource nginxExtension 'Microsoft.Compute/virtualMachines/extensions@2025-11-01' = {
  parent: vm
  name: 'installNginx'
  location: location
  tags: resourceTags
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'apt-get update && apt-get install -y nginx && echo "<h1>${vmName}</h1>" > /var/www/html/index.html'
    }
  }
}

output vmName string = vm.name
output publicIpAddress string = pip.properties.ipAddress
output fqdn string = pip.properties.dnsSettings.fqdn
