// ──────────────────────────────────────────────────────────────────────────────
// network.bicep — VNet + subnets + NSGs. Mirror of the "network" Terraform module
// and step [7] of provision.sh
//
// NSGs are attached to their subnets inline (subnet.properties.networkSecurityGroup)
// rather than via a separate association resource — the idiomatic Bicep pattern,
// avoiding the extra "association" resource type that azurerm requires in Terraform.
// ──────────────────────────────────────────────────────────────────────────────

@description('Learner identifier used for resource naming (firstname-lastname)')
param owner string

@description('Azure region for network resources')
param location string

@description('Tags to apply to all resources in this module')
param tags object

var vnetName = 'vnet-${owner}-bcp'
var nsgFrontendName = 'nsg-frontend-${owner}-bcp'
var nsgBackendName = 'nsg-backend-${owner}-bcp'

resource nsgFrontend 'Microsoft.Network/networkSecurityGroups@2024-10-01' = {
  name: nsgFrontendName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        // TP: source '*' volontaire — cf. ps-rule.yaml (Azure.NSG.AnyInboundSource)
        name: 'Allow-HTTP'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Allow-HTTPS'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        // Explicit deny — good practice even though Azure denies by default at priority 65500
        name: 'Deny-All-Inbound'
        properties: {
          priority: 4000
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Deny-All-Outbound'
        properties: {
          priority: 4000
          direction: 'Outbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource nsgBackend 'Microsoft.Network/networkSecurityGroups@2024-10-01' = {
  name: nsgBackendName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-From-Frontend'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '10.0.1.0/24'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Deny-All-Inbound'
        properties: {
          priority: 4000
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Deny-All-Outbound'
        properties: {
          priority: 4000
          direction: 'Outbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-10-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'subnet-frontend'
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: nsgFrontend.id
          }
        }
      }
      {
        name: 'subnet-backend'
        properties: {
          addressPrefix: '10.0.2.0/24'
          networkSecurityGroup: {
            id: nsgBackend.id
          }
        }
      }
    ]
  }
}

@description('Name of the VNet')
output vnetName string = vnet.name

@description('Resource ID of the VNet')
output vnetId string = vnet.id

@description('Resource ID of subnet-frontend')
output subnetFrontendId string = vnet.properties.subnets[0].id

@description('Resource ID of subnet-backend')
output subnetBackendId string = vnet.properties.subnets[1].id

@description('Name of the NSG attached to subnet-frontend')
output nsgFrontendName string = nsgFrontend.name

@description('Name of the NSG attached to subnet-backend')
output nsgBackendName string = nsgBackend.name
