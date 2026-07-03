## Description

<!-- Décrire les ressources Bicep ajoutées ou modifiées -->

## Checklist

- [ ] `bicep build` exécuté sans erreur (`az bicep build --file bicep/main.bicep`)
- [ ] `bicep lint` / analyseur Bicep sans erreur
- [ ] `az deployment group validate` passe sans erreur
- [ ] `az deployment group what-if` revu et approuvé
- [ ] PSRule for Azure passe sans erreur bloquante
- [ ] Tags `managed_by: 'bicep'` présents sur toutes les ressources
- [ ] Aucun secret / valeur sensible en dur dans les fichiers `.bicep` ou `.bicepparam`

## Ressources impactées

<!-- Liste des ressources créées / modifiées / supprimées -->

## What-if (extrait)

```
<!-- Coller les lignes clés du what-if ici -->
```
