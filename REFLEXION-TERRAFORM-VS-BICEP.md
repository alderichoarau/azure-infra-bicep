# Réflexion — Terraform vs Bicep

À compléter après avoir provisionné puis détruit vos ressources via les workflows GitHub Actions (`bicep-provision.yml` et `bicep-destroy.yml`).

## 1. Gestion de l'état

*Terraform maintient un fichier d'état (`.tfstate`) séparé de l'infrastructure réelle ; Bicep n'en a pas et s'appuie uniquement sur ce qu'Azure Resource Manager voit dans le resource group. Quels avantages et quels inconvénients concrets cela entraîne-t-il ?*

_Votre réponse :_

## 2. Portabilité multi-cloud

*Terraform peut piloter plusieurs fournisseurs (AWS, GCP, Azure...) avec le même outil ; Bicep est spécifique à Azure. Dans quel contexte cet avantage de Terraform serait-il déterminant pour vous, et dans quel contexte serait-il sans intérêt ?*

_Votre réponse :_

## 3. Support des nouveaux services Azure

*Bicep bénéficie en général d'un support "day one" des nouvelles ressources/API Azure ; le provider Terraform `azurerm` peut avoir du retard. Avez-vous rencontré (ou pouvez-vous imaginer) une situation où ce délai poserait un vrai problème ?*

_Votre réponse :_

## 4. Syntaxe et écosystème de modules

*Comparez la lisibilité du HCL (Terraform) et du Bicep sur les ressources que vous avez écrites dans les deux TP, ainsi que la richesse de leurs écosystèmes de modules réutilisables. Qu'est-ce qui vous a semblé le plus rapide à écrire, et pourquoi ?*

_Votre réponse :_

## 5. Cycle provisioning/destruction en CI

*Terraform sait quoi détruire grâce à son état ; Bicep/ARM n'a pas cette mémoire et votre workflow `bicep-destroy.yml` doit donc cibler explicitement un resource group. Lequel des deux modèles vous semble le plus sûr à intégrer dans une CI partagée par toute la promotion, et pourquoi ?*

_Votre réponse :_
