// Reusable network module: NSG + VNet/subnet

@description('Naming prefix')
param namePrefix string

@description('Region')
param location string

@description('VNet address space')
param addressPrefix string = '10.30.0.0/16'

@description('Subnet prefix')
param subnetPrefix string = '10.30.1.0/24'

@description('Source IP allowed over SSH')
param allowedSshSourceIp string

var nsgName = '${namePrefix}-nsg'
var vnetName = '${namePrefix}-vnet'
var subnetName = 'snet-app'

// See README — used to scope destruction to this module's resources only.
var resourceTags = {
  managed_by: 'bicep'
  tp: 'az104-compute'
  exercise: 'bonus-modules'
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
        addressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

output subnetId string = '${vnet.id}/subnets/${subnetName}'
output vnetId string = vnet.id
output nsgId string = nsg.id
