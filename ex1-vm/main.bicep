// AZ-104 Compute - Exercise 1
// Linux VM: network, NSG, public IP, VM + nginx extension

@description('Prefix used to name every resource')
param namePrefix string = 'simplon-tp104'

@description('Deployment region')
param location string = resourceGroup().location

@description('VM admin username')
param adminUsername string = 'azureuser'

@description('SSH public key (content of id_rsa.pub or id_ed25519.pub)')
@secure()
param adminPublicKey string

@description('Source IP (CIDR) allowed to connect over SSH, e.g. 90.12.34.56/32')
param allowedSshSourceIp string

@description('VM size')
param vmSize string = 'Standard_D2s_v3'

@description('Size (GB) of the attached data disk')
param dataDiskSizeGb int = 32

var vnetName = '${namePrefix}-vnet'
var subnetName = 'snet-vm'
var nsgName = '${namePrefix}-nsg-vm'
var pipName = '${namePrefix}-pip-vm'
var nicName = '${namePrefix}-nic-vm'
var vmName = '${namePrefix}-vm01'

// See README — used to scope destruction to this template's resources only.
var resourceTags = {
  managed_by: 'bicep'
  tp: 'az104-compute'
  exercise: 'ex1-vm'
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2025-07-01' = {
  name: nsgName
  location: location
  tags: resourceTags
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-Restricted'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: allowedSshSourceIp
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'Allow-HTTP'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2025-07-01' = {
  name: vnetName
  location: location
  tags: resourceTags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.10.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.10.1.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
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
      domainNameLabel: toLower('${namePrefix}-vm01-${uniqueString(resourceGroup().id)}')
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
            id: '${vnet.id}/subnets/${subnetName}'
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
      dataDisks: [
        {
          lun: 0
          createOption: 'Empty'
          diskSizeGB: dataDiskSizeGb
          managedDisk: {
            storageAccountType: 'Standard_LRS'
          }
        }
      ]
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

// Installs nginx and serves the VM hostname — AZ-104 module 1 "extensions" objective.
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
      commandToExecute: 'apt-get update && apt-get install -y nginx && echo "<h1>TP Bicep - $(hostname)</h1>" > /var/www/html/index.html'
    }
  }
}

output vmName string = vm.name
output publicIpAddress string = pip.properties.ipAddress
output fqdn string = pip.properties.dnsSettings.fqdn
output sshCommand string = 'ssh ${adminUsername}@${pip.properties.ipAddress}'
