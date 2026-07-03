# azure-infra-bicep

Infrastructure Azure provisionnée avec Bicep — contexte formation PRF2026.

Miroir Bicep des projets [azure-infra-cli](https://github.com/hoaraualderic/azure-infra-cli) (scripts Bash/PowerShell) et [azure-infra-terraform](https://github.com/hoaraualderic/azure-infra-terraform) (Terraform).

## Ressources déployées

| Ressource | Nom généré | Description |
|-----------|-----------|-------------|
| Storage Account | `st<owner>bcp` | Stockage métier — containers `api-logs` (privé) et `api-config` (public) |
| App Service | `app-<owner>-bcp` | Application Python 3.11 sur plan partagé |
| Function App | `fn-<owner>-bcp` | Azure Function Python 3.11 + storage dédié (accès par identité managée) |
| Static Web App | `stapp-<owner>-bcp` | Site statique (Free tier) |
| Container Instance | `aci-<owner>-bcp` | nginx:1.27-alpine exposé en public |
| VNet + subnets + NSG | `vnet-<owner>-bcp` | Réseau avec subnet-frontend et subnet-backend |

> Le Resource Group et l'App Service Plan sont **pré-créés par le formateur** — Bicep ne les gère pas (référencés via `existing` / scope de déploiement).

## Prérequis

- [Azure CLI](https://learn.microsoft.com/fr-fr/cli/azure/install-azure-cli) >= 2.60 connecté (`az login`), avec l'extension Bicep (`az bicep install`)
- Rôle **Contributor** sur le Resource Group cible
- (Optionnel) [PSRule for Azure](https://azure.github.io/PSRule.Rules.Azure/) en local : `Install-Module -Name PSRule.Rules.Azure`

## Utilisation locale

```bash
cd bicep
cp main.bicepparam main.local.bicepparam   # remplir owner/tags, jamais commité

# 1. Compiler / valider localement (aucune connexion Azure requise)
az bicep build --file main.bicep

# 2. Prévisualiser les changements (équivalent `terraform plan`)
az deployment group what-if \
  --resource-group rg-formateur-prf2026 \
  --template-file main.bicep \
  --parameters main.local.bicepparam

# 3. Déployer via une Deployment Stack (équivalent `terraform apply`, avec suivi
#    des ressources gérées pour permettre une suppression propre plus tard)
az stack group create \
  --name stack-prenom-nom-bicep \
  --resource-group rg-formateur-prf2026 \
  --template-file main.bicep \
  --parameters main.local.bicepparam \
  --deny-settings-mode none \
  --action-on-unmanage deleteResources

# 4. Détruire (équivalent `terraform destroy`)
az stack group delete \
  --name stack-prenom-nom-bicep \
  --resource-group rg-prenom-nom \
  --action-on-unmanage deleteAll
```

### Pourquoi une Deployment Stack plutôt que `az deployment group create` ?

Contrairement à Terraform, Bicep/ARM ne maintient pas nativement un état permettant
de savoir « quelles ressources ont été retirées du template et doivent être
supprimées ». Les **Deployment Stacks** (`az stack group ...`) comblent cet écart :
elles suivent l'ensemble des ressources qu'elles gèrent et peuvent les supprimer en
bloc (`--action-on-unmanage deleteAll`), donnant un cycle de vie apply/destroy
comparable à celui de Terraform — sans backend d'état à gérer séparément.

## CI/CD (GitHub Actions)

### Secrets requis

| Secret | Description |
|--------|-------------|
| `AZURE_CLIENT_ID` | Client ID du Service Principal (OIDC) |
| `AZURE_TENANT_ID` | Tenant ID Azure AD |
| `AZURE_SUBSCRIPTION_ID` | ID de la subscription |
| `AZURE_OWNER` | Identifiant apprenant (`prenom-nom`) |
| `AZURE_RG_NAME` | Nom du Resource Group (`rg-prenom-nom`) |

### Workflows

| Workflow | Déclencheur | Actions |
|----------|------------|---------|
| **Bicep CI** (`.github/workflows/ci.yml`) | Push `main` / PR | `bicep build` (compile + lint via `bicepconfig.json`), format check, PSRule for Azure |
| **Bicep Deploy** (`.github/workflows/deploy.yml`) | Manuel (`workflow_dispatch`) | whatif / deploy / destroy |

## Bonnes pratiques Bicep mises en œuvre

- **Modules par ressource** (`bicep/modules/`) — un fichier par composant, param/resource/output regroupés (convention Bicep, pas de `variables.tf` séparé).
- **`existing` pour les ressources pré-créées** — Resource Group cible (scope de déploiement) et App Service Plan partagé (`scope: resourceGroup(sharedResourceGroupName)`), jamais gérés par ce template.
- **`bicepconfig.json`** — analyseur Bicep configuré en erreurs bloquantes (secrets en dur, URLs hardcodées, localisation hardcodée, paramètres/variables inutilisés, API versions récentes, etc.), exécuté automatiquement à chaque `bicep build`.
- **Décorateurs de paramètres** (`@description`, `@minLength`, `@maxLength`) sur toutes les entrées ; pas de valeurs sensibles avec valeur par défaut en clair.
- **`.bicepparam`** (format natif, typé) plutôt que l'ancien `parameters.json` — validé par IntelliSense/compilateur.
- **Aucun backend d'état à gérer** — contrairement à Terraform, l'état est géré par Azure Resource Manager ; les Deployment Stacks apportent le suivi nécessaire pour un `destroy` propre.
- **Identités managées partout** — App Service, Function App et Container Instance utilisent `SystemAssigned` ; le Function App accède à son storage dédié via RBAC (`Storage Blob Data Owner`) et non via clé de compte.
- **NSG attaché en ligne au subnet** (`subnet.properties.networkSecurityGroup`) plutôt qu'une ressource d'association séparée — pattern idiomatique Bicep/ARM.
- **Tags cohérents** (`managed_by: 'bicep'`) fusionnés via `union()`, pour coexister sans collision avec les ressources `managed_by=cli` / `managed_by=terraform`.
- **Suffixe `bcp`** sur tous les noms globalement uniques (storage accounts, DNS label de l'ACI) pour éviter toute collision avec les variantes CLI (`-cli`) et Terraform (`-tf`) du même TP dans la même subscription.
- **Analyse de sécurité PSRule for Azure** en CI (équivalent Checkov), avec exceptions documentées et justifiées dans `ps-rule.yaml` (miroir des commentaires `checkov:skip` du projet Terraform).
- **OIDC (`azure/login@v3`)** pour l'authentification CI — aucun secret client statique.

### Limite connue

Bicep ne propose pas d'équivalent direct à la validation `can(regex(...))` de
Terraform sur les paramètres (pas de décorateur `@pattern`). La convention de
nommage `owner` (minuscules, tirets) n'est donc pas validée à la compilation —
seule la longueur l'est (`@minLength`/`@maxLength`). À renforcer via une Azure
Policy ou une étape de vérification en CI si nécessaire.

## Structure

```
azure-infra-bicep/
├── bicep/
│   ├── main.bicep          # Orchestration des modules + ressources inline
│   ├── main.bicepparam     # Paramètres (format natif Bicep)
│   ├── bicepconfig.json    # Config de l'analyseur/linter Bicep
│   └── modules/
│       ├── storage.bicep       # Storage Account + containers
│       ├── app-service.bicep   # azurerm_linux_web_app équivalent
│       ├── function-app.bicep  # Function App + storage dédié + RBAC
│       ├── container.bicep     # Azure Container Instance
│       └── network.bicep       # VNet + subnets + NSGs
├── ps-rule.yaml             # Config PSRule for Azure (scan sécurité)
└── .github/
    └── workflows/
        ├── ci.yml           # build, lint, PSRule
        └── deploy.yml       # whatif / deploy / destroy (manuel)
```

---

Azure DevSecOps Training — Simplon
