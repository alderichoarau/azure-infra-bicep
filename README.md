# azure-infra-bicep

Bicep implementation of the Microsoft Learn path
[AZ-104 — Manage compute resources](https://learn.microsoft.com/en-us/training/paths/az-104-manage-compute-resources/):
the same VM, scale set, App Service and Container Instances resources that path has you create via the
portal/CLI, deployed here as code instead.

> Based on the TP Bicep Azure assignment and its answer key (Simplon — DevOps Azure training).

## What's deployed

Each exercise is independent (its own network, no cross-dependency) and maps to one step of the AZ-104 path:

| Folder | AZ-104 module | Resources |
|---|---|---|
| [`ex1-vm/`](ex1-vm/) | VM overview | VNet + subnet, NSG (SSH restricted to one IP, HTTP open), public IP, Linux VM (Ubuntu 22.04, SSH key only) with a data disk, `CustomScript` extension (nginx) |
| [`ex2-vmss-autoscale/`](ex2-vmss-autoscale/) | Configure VM availability | Standard Load Balancer, Virtual Machine Scale Set (≥ 2 instances), CPU autoscale (70%/30%) plus a schedule-based profile (business-hours scale-out/-in) |
| [`ex3-appservice/`](ex3-appservice/) | Configure App Service plans/Azure App Service | Linux App Service Plan (S1) with CPU autoscale, containerized Web App, `staging` deployment slot, per-slot `appSettings` |
| [`ex4-container-instances/`](ex4-container-instances/) | Configure Azure Container Instances | 2-container group (exposed web + logging sidecar) sharing an `azureFile` volume, environment variables, public DNS |
| [`bonus-modules/`](bonus-modules/) | — (modularization) | Reusable `network.bicep` + `vm.bicep` modules, orchestrated with a `for` loop (`vmCount` identical VMs) |

Every resource is tagged **`managed_by: 'bicep'`** (+ `tp: 'az104-compute'`, `exercise: '<exercise-name>'`) — see below.

## Tag and scoped destruction (`managed_by = bicep`)

The target resource group (`rg-formateur-prf2026` in CI, via the GitHub variable `AZURE_RG_NAME`) is **shared**
across all 5 exercises, and possibly other students or tools (CLI, Terraform). Two things keep a
deploy/destroy from ever touching more than its own exercise:

1. **`managed_by: 'bicep'` tag** on every resource — simple identification regardless of tool
   (`az resource list --tag managed_by=bicep`, Cost Management, Resource Graph).
2. **One Deployment Stack per exercise** (`stack-<exercise>`) — this is what actually drives deletion.
   `scripts/cleanup.sh` runs `az stack group delete --action-on-unmanage deleteAll`, which removes only the
   resources *that specific stack* created, in dependency order. The resource group, other exercises, and
   anything from another tool are left alone.

## Usage

```bash
# Compile every template without deploying anything
./scripts/validate-bicep.sh

# Preview what a deployment would create/change/delete, without deploying
# anything — Bicep's equivalent of `terraform plan`
./scripts/deploy.sh ex1-vm rg-tp104-ex1 francecentral --what-if

# Deploy one exercise (creates the resource group if missing, auto-detects
# your SSH public key and source IP for exercises that need one)
./scripts/deploy.sh ex1-vm rg-tp104-ex1 francecentral

# Functional check (same as CI)
./scripts/verify.sh ex1-vm rg-tp104-ex1

# Teardown — destroys ONLY this exercise's resources
./scripts/cleanup.sh ex1-vm rg-tp104-ex1 --wait
```

Repeat for `ex2-vmss-autoscale`, `ex3-appservice`, `ex4-container-instances`, `bonus-modules`.

## CI/CD (GitHub Actions)

| Name | Type | Purpose |
|------|------|---------|
| `AZURE_CLIENT_ID` | Secret | OIDC Service Principal client ID |
| `AZURE_TENANT_ID` | Secret | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Secret | Subscription ID |
| `AZURE_RG_NAME` | **Variable** (not secret) | Trainer-provisioned resource group name, shared across exercises/students |

| Workflow | Trigger | Role |
|----------|---------|------|
| [`bicep-lint.yml`](.github/workflows/bicep-lint.yml) | Push `main` / PR touching `*.bicep` | `az bicep build` matrix over the 5 exercises + PSRule for Azure scan. No Azure credentials needed. |
| [`bicep-provision.yml`](.github/workflows/bicep-provision.yml) | Manual (exercise + region + `action`: `deploy` or `whatif`) | OIDC login → `deploy.sh` (Deployment Stack, or `--what-if` preview only) → `verify.sh` |
| [`bicep-destroy.yml`](.github/workflows/bicep-destroy.yml) | Manual (exercise) | OIDC login → `cleanup.sh --yes --wait` — removes only that exercise's `managed_by=bicep` resources |

Provision and destroy are separate, manually-triggered workflows (mirroring `terraform apply` /
`terraform destroy`) rather than one job that tears itself down — so the Actions tab shows a clear
provision run followed by a destroy run.

> ⚠️ `bicep-provision.yml` creates real, billed resources (including an S1 App Service Plan for exercise 3).
> It's not wired to `push`/`pull_request` — trigger it manually and follow up with `bicep-destroy.yml`.

## Structure

```
azure-infra-bicep/
├── ex1-vm/                       main.bicep + main.parameters.json
├── ex2-vmss-autoscale/           main.bicep + main.parameters.json
├── ex3-appservice/                main.bicep + main.parameters.json
├── ex4-container-instances/       main.bicep + main.parameters.json
├── bonus-modules/                 main.bicep + modules/{network,vm}.bicep + main.parameters.json
├── scripts/
│   ├── deploy.sh                  deploys one exercise (Deployment Stack, auto SSH key + IP)
│   ├── verify.sh                  functional check (curl with retries)
│   ├── cleanup.sh                 destroys ONLY one exercise's managed_by=bicep resources
│   └── validate-bicep.sh          compiles every template without deploying
├── bicepconfig.json                Bicep linter config (root — covers every exercise)
├── ps-rule.yaml                    PSRule for Azure config (security scan)
├── REFLEXION-TERRAFORM-VS-BICEP.md Terraform vs Bicep reflection (assignment questions, in French)
└── .github/
    └── workflows/
        ├── bicep-lint.yml          build + lint + PSRule (automatic)
        ├── bicep-provision.yml     real deployment (manual)
        └── bicep-destroy.yml       scoped destruction (manual)
```

---

Azure DevSecOps Training — Simplon
