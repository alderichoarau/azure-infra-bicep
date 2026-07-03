// ──────────────────────────────────────────────────────────────────────────────
// container.bicep — Azure Container Instance (nginx). Mirror of the "container"
// Terraform module and step [5] of provision.sh
// ──────────────────────────────────────────────────────────────────────────────

@description('Learner identifier used for resource naming (firstname-lastname)')
param owner string

@description('Azure region for the container instance')
param location string

@description('Tags to apply to all resources in this module')
param tags object

// Also used as the DNS name label — must be globally unique within the region
var containerGroupName = 'aci-${owner}-bcp'

resource aci 'Microsoft.ContainerInstance/containerGroups@2025-09-01' = {
  name: containerGroupName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    osType: 'Linux'
    // TP: exception volontaire — IP publique pour un conteneur nginx de démonstration.
    // Cf. ps-rule.yaml (règle Azure.Container.PublicIP supprimée pour aci-*-bcp)
    ipAddress: {
      type: 'Public'
      dnsNameLabel: containerGroupName
      ports: [
        {
          port: 80
          protocol: 'TCP'
        }
      ]
    }
    containers: [
      {
        name: 'nginx'
        properties: {
          image: 'nginx:1.27-alpine'
          resources: {
            requests: {
              cpu: json('0.5')
              memoryInGB: json('0.5')
            }
          }
          ports: [
            {
              port: 80
              protocol: 'TCP'
            }
          ]
          environmentVariables: [
            {
              name: 'OWNER'
              value: owner
            }
            {
              name: 'ENVIRONMENT'
              value: 'tp'
            }
          ]
        }
      }
    ]
  }
}

@description('FQDN of the Container Instance')
output fqdn string = aci.properties.ipAddress.fqdn

@description('Public IP address of the Container Instance')
output ipAddress string = aci.properties.ipAddress.ip
