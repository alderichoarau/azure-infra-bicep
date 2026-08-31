// AZ-104 Compute - Bonus
// Orchestrator: network (module) + N VMs (module, for-loop)

@description('Naming prefix')
param namePrefix string = 'simplon-tp104-bonus'

@description('Deployment region')
param location string = resourceGroup().location

@description('Admin username')
param adminUsername string = 'azureuser'

@description('SSH public key')
@secure()
param adminPublicKey string

@description('Source IP (CIDR) allowed over SSH')
param allowedSshSourceIp string

@description('Number of identical VMs to deploy via vm.bicep')
@minValue(1)
@maxValue(5)
param vmCount int = 2

module network 'modules/network.bicep' = {
  name: 'deploy-network'
  params: {
    namePrefix: namePrefix
    location: location
    allowedSshSourceIp: allowedSshSourceIp
  }
}

module vms 'modules/vm.bicep' = [
  for i in range(0, vmCount): {
    name: 'deploy-vm-${i}'
    params: {
      namePrefix: namePrefix
      location: location
      vmIndex: i
      subnetId: network.outputs.subnetId
      adminUsername: adminUsername
      adminPublicKey: adminPublicKey
    }
  }
]

output vmNames array = [for i in range(0, vmCount): vms[i].outputs.vmName]
output vmPublicIps array = [for i in range(0, vmCount): vms[i].outputs.publicIpAddress]
