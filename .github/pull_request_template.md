## Description

<!-- Describe the Bicep resources added/changed, and which exercise -->

## Checklist

- [ ] `bicep build` passes for the exercise (`az bicep build --file <exercise>/main.bicep`)
- [ ] Bicep linter passes (`bicepconfig.json`)
- [ ] `scripts/validate-bicep.sh` passes for all templates
- [ ] PSRule for Azure passes without an unjustified failure (`ps-rule.yaml`)
- [ ] `managed_by: 'bicep'` tag present on every resource added/changed
- [ ] No secrets/sensitive values hardcoded in `.bicep` or `main.parameters.json` (SSH key, real IP → `CHANGE_ME`)
- [ ] `bicep-provision.yml` ran successfully for this exercise (link the run)
- [ ] `bicep-destroy.yml` ran successfully right after (link the run)

## Resources affected

<!-- Created / modified / deleted -->

## Functional verification

<!-- Paste the key output from scripts/verify.sh or the "provision" run -->
