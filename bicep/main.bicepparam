// Copy this file to main.local.bicepparam and fill in your values
// main.local.bicepparam is gitignored — never commit it with real values

using 'main.bicep'

// Your learner identifier (firstname-lastname, lowercase, hyphens only)
param owner = 'prenom-nom'

// Azure region — default is francecentral, change only if instructed
param location = 'francecentral'

// Shared infrastructure (pre-created by trainer — do not change)
// param sharedResourceGroupName = 'rg-shared-prf2026'
// param sharedPlanName = 'plan-npr-prf2026'

// Optional extra tags
// param tags = {
//   project: 'tp-azure'
// }
