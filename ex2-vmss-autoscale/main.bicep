// AZ-104 Compute - Exercise 2
// Availability and scaling: Load Balancer + VMSS + CPU-based autoscale

@description('Prefix used to name every resource')
param namePrefix string = 'simplon-tp104'

@description('Deployment region')
param location string = resourceGroup().location

@description('Instances admin username')
param adminUsername string = 'azureuser'

@description('SSH public key (content of id_rsa.pub or id_ed25519.pub)')
@secure()
param adminPublicKey string

@description('Source IP (CIDR) allowed to connect over SSH, e.g. 90.12.34.56/32')
param allowedSshSourceIp string

@description('Scale set instance size')
param vmSize string = 'Standard_B1s'

@description('Initial instance count')
param initialCapacity int = 2

@description('Minimum instance count allowed by autoscale')
param minCapacity int = 2

@description('Maximum instance count allowed by autoscale')
param maxCapacity int = 5

@description('Minimum instance count during the scheduled business-hours profile')
param businessHoursMinCapacity int = 3

@description('Windows time zone ID used by the schedule-based autoscale profiles')
param autoscaleTimeZone string = 'Romance Standard Time'

var vnetName = '${namePrefix}-vnet-ha'
var subnetName = 'snet-vmss'
var nsgName = '${namePrefix}-nsg-vmss'
var pipName = '${namePrefix}-pip-lb'
var lbName = '${namePrefix}-lb'
var vmssName = '${namePrefix}-vmss'
var backendPoolName = 'beap-web'
var probeName = 'probe-http'
var lbRuleName = 'rule-http'
var natPoolName = 'natpool-ssh'

// See README — used to scope destruction to this template's resources only.
var resourceTags = {
  managed_by: 'bicep'
  tp: 'az104-compute'
  exercise: 'ex2-vmss-autoscale'
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
          destinationPortRange: '50000-50100'
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
      {
        name: 'Allow-AzureLoadBalancer'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
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
        '10.20.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.20.1.0/24'
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
      domainNameLabel: toLower('${namePrefix}-lb-${uniqueString(resourceGroup().id)}')
    }
  }
}

resource lb 'Microsoft.Network/loadBalancers@2025-07-01' = {
  name: lbName
  location: location
  tags: resourceTags
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'feip-front'
        properties: {
          publicIPAddress: {
            id: pip.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: backendPoolName
      }
    ]
    probes: [
      {
        name: probeName
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
    loadBalancingRules: [
      {
        name: lbRuleName
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, 'feip-front')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, backendPoolName)
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', lbName, probeName)
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          idleTimeoutInMinutes: 5
        }
      }
    ]
    inboundNatPools: [
      {
        name: natPoolName
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, 'feip-front')
          }
          protocol: 'Tcp'
          frontendPortRangeStart: 50000
          frontendPortRangeEnd: 50100
          backendPort: 22
        }
      }
    ]
  }
}

resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2025-11-01' = {
  name: vmssName
  location: location
  tags: resourceTags
  sku: {
    name: vmSize
    tier: 'Standard'
    capacity: initialCapacity
  }
  properties: {
    overprovision: false
    upgradePolicy: {
      mode: 'Automatic'
    }
    virtualMachineProfile: {
      osProfile: {
        computerNamePrefix: 'web'
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
        networkInterfaceConfigurations: [
          {
            name: 'nic-vmss'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig1'
                  properties: {
                    subnet: {
                      id: '${vnet.id}/subnets/${subnetName}'
                    }
                    loadBalancerBackendAddressPools: [
                      {
                        id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, backendPoolName)
                      }
                    ]
                    loadBalancerInboundNatPools: [
                      {
                        id: resourceId('Microsoft.Network/loadBalancers/inboundNatPools', lbName, natPoolName)
                      }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
      extensionProfile: {
        extensions: [
          {
            name: 'installNginx'
            properties: {
              publisher: 'Microsoft.Azure.Extensions'
              type: 'CustomScript'
              typeHandlerVersion: '2.1'
              autoUpgradeMinorVersion: true
              settings: {
                commandToExecute: 'apt-get update && apt-get install -y nginx stress-ng && echo "<h1>Instance $(hostname)</h1>" > /var/www/html/index.html'
              }
            }
          }
        ]
      }
    }
  }
  dependsOn: [
    lb
  ]
}

resource autoscale 'Microsoft.Insights/autoscalesettings@2022-10-01' = {
  name: '${namePrefix}-autoscale'
  location: location
  tags: resourceTags
  properties: {
    enabled: true
    targetResourceUri: vmss.id
    profiles: [
      {
        name: 'profil-cpu'
        capacity: {
          minimum: string(minCapacity)
          maximum: string(maxCapacity)
          default: string(initialCapacity)
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricResourceUri: vmss.id
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
              metricName: 'Percentage CPU'
              metricResourceUri: vmss.id
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
      // Predictable schedule-based scaling on top of the CPU profile above:
      // scale out at the start of business hours, back down in the evening.
      // 'profil-cpu' (no recurrence) stays the default outside these windows
      // (nights, weekends) — see https://learn.microsoft.com/azure/azure-monitor/autoscale/autoscale-overview#autoscale-profiles.
      {
        name: 'profil-heures-ouvrees'
        capacity: {
          minimum: string(businessHoursMinCapacity)
          maximum: string(maxCapacity)
          default: string(businessHoursMinCapacity)
        }
        recurrence: {
          frequency: 'Week'
          schedule: {
            timeZone: autoscaleTimeZone
            days: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
            hours: [8]
            minutes: [0]
          }
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricResourceUri: vmss.id
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
        ]
      }
      {
        name: 'profil-soir'
        capacity: {
          minimum: string(minCapacity)
          maximum: string(maxCapacity)
          default: string(minCapacity)
        }
        recurrence: {
          frequency: 'Week'
          schedule: {
            timeZone: autoscaleTimeZone
            days: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
            hours: [18]
            minutes: [0]
          }
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricResourceUri: vmss.id
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

output loadBalancerPublicIp string = pip.properties.ipAddress
output loadBalancerFqdn string = pip.properties.dnsSettings.fqdn
output vmssName string = vmss.name
output sshViaNatExample string = 'ssh -p 50000 ${adminUsername}@${pip.properties.ipAddress}  (one instance; port varies per NAT mapping, see portal)'
