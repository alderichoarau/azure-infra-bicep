# TP Bicep — Ressources de calcul Azure

**Durée estimée :** 2 jours (environ 12h)
**Prérequis :** notions de base Bicep (`resource`/`param`/`var`/`output`, `az deployment group create` — voir le module Microsoft Learn [Fondamentaux de Bicep](https://learn.microsoft.com/fr-fr/training/modules/create-first-bicep-template/) si besoin), Azure CLI installé, un abonnement Azure avec le rôle Contributeur
**Environnement :**
- macOS / Linux → Terminal natif
- Windows → **Git Bash** (déjà installé avec Git)
- VS Code avec l'extension Bicep recommandée

**Support de référence :** parcours Microsoft Learn [AZ-104 : Déployer et gérer les ressources de calcul Azure](https://learn.microsoft.com/fr-fr/training/paths/az-104-manage-compute-resources/).

---

## Objectifs du TP

Le parcours Microsoft Learn ci-dessus vous fait manipuler des VM, des scale sets, des plans App Service, des Web Apps et des Container Instances via le **portail Azure** ou l'**Azure CLI**. Dans ce TP, vous allez déployer exactement les mêmes types de ressources, mais en **infrastructure as code avec Bicep** :

- décrire une infrastructure de façon déclarative, versionnable et reproductible ;
- comprendre les dépendances entre ressources Azure (réseau, sécurité, calcul) telles qu'exprimées dans un template ;
- pratiquer les briques de langage Bicep : paramètres, variables, ressources, dépendances implicites, sorties (`outputs`), modules et boucles.

À l'issue du TP, vous saurez traduire en Bicep chacun des 5 modules du parcours AZ-104 cité plus haut.

---

## Bicep pour utilisateurs Terraform

Vous connaissez déjà Terraform : les concepts d'infrastructure as code (ressources, paramètres, dépendances, modules, sorties) vous sont donc familiers. Ce qui change avec Bicep, c'est surtout la syntaxe et l'absence de state. Table de correspondance rapide :

| Terraform (HCL) | Bicep | À noter |
|---|---|---|
| `resource "type" "name" { }` | `resource name 'type@apiVersion' = { }` | Bicep exige la version d'API dans le type ; le nom symbolique n'a pas de guillemets |
| `variable "x" {}` puis `var.x` | `param x type` puis `x` | `param` Bicep ≈ `variable` Terraform — **pas** `var`, qui désigne autre chose |
| `local.x` | `var x = ...` | inversé par rapport à l'intuition Terraform (`var` = valeur calculée locale, pas une entrée) — piège classique |
| `output "x" {}` | `output x type = ...` | même rôle, syntaxe plus proche |
| `resource_a.id` (référence) | `resourceA.id` | quasi identique — dépendances implicites dans les deux langages |
| `module "x" { source = ... }` | `module x 'path.bicep' = { params: {} }` | même logique |
| fichier `.tfstate` | *(aucun fichier d'état)* | Bicep/ARM lit l'état réel depuis Azure à chaque déploiement — voir question 1 de la réflexion |
| `terraform plan` | `az deployment group what-if` | équivalent direct |
| `terraform apply` | `az deployment group create` (ou `az stack group create`) | — |
| `terraform destroy` | pas de commande native — `az group delete` ou une Deployment Stack | voir question 5 de la réflexion |

Le point le plus déroutant pour un habitué Terraform : Bicep **compile vers de l'ARM JSON** (`az bicep build`) — c'est un transpileur, pas un moteur d'exécution avec graphe d'état comme Terraform. C'est pour ça qu'il n'y a pas d'équivalent direct de `.tfstate`, et pourquoi le TP insiste autant sur le cycle provisioning/destruction en CI (étape 5 de la réflexion) : sans état, c'est à vous de savoir explicitement ce qui doit être détruit.

---

## Mise en place

```bash
# Cloner le repo du TP
git clone <url-fournie-par-le-formateur>
cd TP-Bicep-Azure

# Vérifier que vous êtes bien dans le dossier
pwd
ls
```

Une paire de clés SSH locale est nécessaire pour les exercices avec VM. Si vous n'en avez pas :

```bash
ssh-keygen -t ed25519 -C "tp-bicep-az104"
```

**Règles pour tout le TP :**
- **Un resource group distinct par exercice**, nommé `rg-<votre-alias>-tp104-exY` (ex : `rg-jdupont-tp104-ex1`).
- **Aucun secret en dur dans votre code** : la clé SSH publique et votre IP source se passent en paramètre au moment du déploiement (`--parameters cle=valeur`), jamais codées dans un fichier `.bicep` ni committées avec une vraie valeur dans Git.
- Chaque exercice se termine par une vérification (`curl`, `ssh`, commande `az`) : sans vérification qui passe, l'exercice n'est pas validé même si `az deployment group create` répond `Succeeded`.
- **Nettoyage obligatoire en fin de journée** (voir tout en bas).

---

## Étape 1 — Machine virtuelle Linux (Jour 1, matin)

### Concept

Correspond au module *"Présentation des machines virtuelles Azure"*. Une VM Azure ne se résume pas à la machine elle-même : elle dépend d'un réseau virtuel, d'un sous-réseau, d'un groupe de sécurité réseau (NSG), d'une carte réseau (NIC) et, si on veut y accéder depuis Internet, d'une IP publique. En Bicep, chacun de ces éléments est une ressource à part entière, reliée aux autres par des références (`nic.id`, `vnet.id`, etc.) qui créent des dépendances implicites — Azure Resource Manager déploie alors dans le bon ordre sans que vous ayez à l'écrire vous-même.

### Exercice 1.1 — Réseau et sécurité

Écrivez un fichier `main.bicep` qui déploie :

1. un réseau virtuel (VNet) avec un subnet dédié ;
2. un groupe de sécurité réseau (NSG) associé au subnet, autorisant :
   - le port 22 (SSH) **uniquement depuis votre IP publique** (paramètre — jamais `0.0.0.0/0`) ;
   - le port 80 (HTTP) depuis n'importe où.

> **Astuce :** `Microsoft.Network/networkSecurityGroups` puis `Microsoft.Network/virtualNetworks`, avec le NSG référencé dans la propriété `networkSecurityGroup` du subnet.

### Exercice 1.2 — La VM et son extension

Complétez le même template avec :

3. une IP publique de SKU Standard avec un nom DNS ;
4. une VM Linux (Ubuntu 22.04 LTS) authentifiée par clé SSH uniquement (pas de mot de passe : `osProfile.linuxConfiguration.disablePasswordAuthentication: true`) ;
5. une extension `CustomScript` (`Microsoft.Compute/virtualMachines/extensions`) qui installe `nginx` au démarrage et remplace la page d'accueil par une page affichant le nom d'hôte de la machine.

Paramétrez au minimum : le préfixe de nommage, la taille de VM (`Standard_B1s` par défaut), le nom d'administrateur, la clé publique SSH et l'IP source autorisée.

### Vérification

```bash
az deployment group create --resource-group <rg> --template-file main.bicep --parameters ...
curl http://<ip-publique-ou-fqdn>
```

doit retourner une page HTML contenant le nom d'hôte de la VM. Une tentative SSH par mot de passe doit être refusée. Une tentative depuis une autre IP que la vôtre doit échouer (bloquée par le NSG).

> ⏱️ L'extension met 1 à 2 minutes à s'exécuter après la fin du déploiement — patience avant de tester `curl`.

### Pour aller plus loin — Étape 1

- Ajoutez un disque de données (`dataDisks`) attaché à la VM.
- Exposez en `output` une commande `ssh` prête à copier-coller.
- Essayez `az deployment group create --confirm-with-what-if` pour voir ce qui va être créé avant de valider.

---

## Étape 2 — Disponibilité et mise à l'échelle (Jour 1, après-midi)

### Concept

Correspond au module *"Configurer la disponibilité des machines virtuelles"*. Une VM unique est un point de défaillance unique. On la remplace par un **Virtual Machine Scale Set** (VMSS) derrière un **Load Balancer**, avec des règles d'**autoscale** qui ajoutent ou retirent des instances selon la charge.

### Exercice 2.1 — Load Balancer et VMSS

1. un Load Balancer Standard public, avec une règle de répartition sur le port 80 et une sonde de santé (`probe`) TCP ;
2. un VMSS Linux (`Microsoft.Compute/virtualMachineScaleSets`), au moins 2 instances, rattaché au backend pool du load balancer ;
3. la même extension `CustomScript` qu'à l'étape 1, pour visualiser la répartition de charge (nom d'hôte affiché).

> **Astuce :** le SKU du VMSS (nom, tier, capacité) se définit au niveau `sku` de la ressource, pas dans `properties`.

### Exercice 2.2 — Autoscale

4. une règle d'autoscale (`Microsoft.Insights/autoscalesettings`) basée sur le CPU : scale-out si le CPU moyen dépasse 70 % pendant 5 minutes, scale-in si le CPU descend sous 30 % pendant 5 minutes, avec un minimum et un maximum d'instances paramétrables.

> **Astuce :** `targetResourceUri` de la règle d'autoscale doit pointer vers l'ID du VMSS (`vmss.id`).

### Vérification

```bash
curl http://<fqdn-du-load-balancer>
```

exécuté plusieurs fois doit afficher des noms d'hôte différents. Pour observer l'autoscale sans attendre une vraie charge, installez `stress-ng` dans votre extension et lancez-le manuellement sur une instance via SSH (prévoyez un moyen de vous connecter individuellement à une instance : indice `inboundNatPools` sur le load balancer).

### Pour aller plus loin — Étape 2

- Ajoutez une règle d'autoscale basée sur le planning (scale-out prévisible le matin, scale-in le soir).
- Testez `az vmss list-instances` pendant une montée en charge pour observer le scale-out en direct.

---

## Étape 3 — App Service Plan et Web App (Jour 2, matin)

### Concept

Correspond aux modules *"Configurer des plans Azure App Service"* et *"Configurer Azure App Service"*. Un plan App Service définit la capacité de calcul (SKU, OS) ; une ou plusieurs Web Apps s'y rattachent. Les **slots de déploiement** permettent de préparer une nouvelle version en parallèle de la production, puis de basculer (swap) sans interruption.

### Exercice 3.1 — Plan et Web App

1. un App Service Plan Linux, en SKU **Standard S1 minimum** (nécessaire pour les slots) ;
2. une Web App conteneurisée (image Docker publique de démonstration) rattachée à ce plan, HTTPS forcé.

> **Astuce :** le nom d'une Web App doit être unique **au niveau mondial** (sous-domaine `*.azurewebsites.net`) — utilisez `uniqueString(resourceGroup().id)` dans le nom. L'image se définit dans `siteConfig.linuxFxVersion` au format `DOCKER|<image>`.

### Exercice 3.2 — Slot de déploiement

3. un slot nommé `staging`, sur le même plan (ressource enfant `Microsoft.Web/sites/slots`, `parent: webApp`), pouvant héberger une version différente.

### Vérification

```bash
curl -I https://<nom-webapp>.azurewebsites.net
curl -I https://<nom-webapp>-staging.azurewebsites.net
```

doivent répondre `200 OK`. Effectuez un swap avec `az webapp deployment slot swap` et vérifiez que le contenu servi en production a changé.

> 💰 **Coût :** un plan S1 tourne même sans trafic. Ne le laissez pas actif en dehors des séances.

### Pour aller plus loin — Étape 3

- Ajoutez des `appSettings` (variables d'environnement) différentes entre production et staging.
- Configurez l'auto-scale du plan App Service lui-même (`Microsoft.Insights/autoscalesettings` sur le plan).

---

## Étape 4 — Azure Container Instances (Jour 2, après-midi)

### Concept

Correspond au module *"Configurer Azure Container Instances"*. ACI permet de lancer un ou plusieurs conteneurs sans gérer de VM ni de cluster. Un **groupe de conteneurs** partage le même cycle de vie réseau : c'est l'unité de déploiement, pas le conteneur individuel.

### Exercice 4.1 — Groupe de deux conteneurs

Déployez un `Microsoft.ContainerInstance/containerGroups` composé de :

1. un conteneur principal exécutant une image web publique de démonstration, exposé sur le port 80 avec un nom DNS public ;
2. un conteneur « sidecar » sans port exposé, qui tourne en tâche de fond (par exemple une boucle qui écrit un message dans les logs toutes les 30 secondes), pour illustrer le partage du cycle de vie réseau du groupe.

Dimensionnez explicitement le CPU et la mémoire de chaque conteneur en paramètres.

> **Astuce :** le nom DNS public (`properties.ipAddress.dnsNameLabel`) doit aussi être unique globalement. Un conteneur sans port exposé n'a simplement pas d'entrée `ports`, mais le port du conteneur principal doit être répété au niveau du groupe (`ipAddress.ports`).

### Vérification

```bash
curl http://<fqdn-du-container-group>
az container logs --resource-group <rg> --name <nom-groupe> --container-name <sidecar>
```

Le `curl` doit répondre avec la page de démonstration. Les logs du sidecar doivent montrer des lignes horodatées récentes.

### Pour aller plus loin — Étape 4

- Ajoutez un volume `azureFile` partagé entre les deux conteneurs.
- Passez des variables d'environnement (`environmentVariables`) au conteneur principal.

---

## Bonus — Modulariser votre code (si le temps le permet)

Reprenez l'étape 1 et découpez votre template en deux **modules Bicep** réutilisables :

- `network.bicep` : NSG + VNet/subnet, qui expose l'ID du subnet en sortie ;
- `vm.bicep` : une VM complète (IP, NIC, VM, extension) à partir d'un ID de subnet reçu en paramètre.

Dans un `main.bicep` orchestrateur, appelez le module réseau une fois, puis le module VM **plusieurs fois via une boucle `for`**, pilotée par un paramètre `vmCount`.

Testez `az deployment group what-if` avant d'appliquer un changement de `vmCount` pour voir ce que Azure prévoit de créer/modifier/supprimer sans le faire réellement.

---

## Réflexion — Terraform vs Bicep (obligatoire)

Vous avez déjà provisionné ce type de ressources Azure avec Terraform sur un précédent TP. Répondez maintenant, dans un fichier `REFLEXION-TERRAFORM-VS-BICEP.md` à la racine de votre dépôt, aux **5 questions** suivantes (quelques phrases par question suffisent — l'objectif est de comparer les deux outils sur des points concrets que vous avez vous-même rencontrés, pas de réciter un cours) :

1. **Gestion de l'état.** Terraform maintient un fichier d'état (`.tfstate`) séparé de l'infrastructure réelle ; Bicep n'en a pas et s'appuie uniquement sur ce qu'Azure Resource Manager voit dans le resource group. Quels avantages et quels inconvénients concrets cela entraîne-t-il (risque de drift, verrouillage d'état en travail à plusieurs, complexité de configuration d'un backend distant, etc.) ?

2. **Portabilité multi-cloud.** Terraform peut piloter plusieurs fournisseurs (AWS, GCP, Azure...) avec le même outil ; Bicep est spécifique à Azure. Dans quel contexte cet avantage de Terraform serait-il déterminant pour vous, et dans quel contexte serait-il sans intérêt ?

3. **Support des nouveaux services Azure.** Bicep, étant l'outil officiel Microsoft compilé directement en ARM, bénéficie en général d'un support "day one" des nouvelles ressources/API Azure ; le provider Terraform `azurerm` dépend d'un travail supplémentaire de la communauté/HashiCorp et peut avoir du retard. Avez-vous rencontré (ou pouvez-vous imaginer) une situation où ce délai poserait un vrai problème ?

4. **Syntaxe et écosystème de modules.** Comparez la lisibilité du HCL (Terraform) et du Bicep sur les ressources que vous avez écrites dans les deux TP, ainsi que la richesse de leurs écosystèmes de modules réutilisables (Terraform Registry vs modules Bicep communautaires/premiers-partis). Qu'est-ce qui vous a semblé le plus rapide à écrire, et pourquoi ?

5. **Cycle provisioning/destruction en CI.** Vous avez maintenant un pipeline GitHub Actions avec un workflow qui provisionne (`bicep-provision.yml`) et un qui détruit (`bicep-destroy.yml`), comme vous l'aviez probablement fait avec `terraform apply`/`terraform destroy`. Terraform sait quoi détruire grâce à son état ; Bicep/ARM n'a pas cette mémoire et votre workflow de destruction doit donc cibler explicitement un resource group. Lequel des deux modèles vous semble le plus sûr à intégrer dans une CI partagée par toute la promotion, et pourquoi ?

## Livrables attendus

Le rendu est **l'URL de votre dépôt GitHub**, contenant :

- le code Bicep de chaque exercice (fichiers `.bicep` + fichiers de paramètres, sans secret en clair) ;
- les deux workflows `.github/workflows/bicep-provision.yml` et `bicep-destroy.yml`, chacun **exécuté au moins une fois** et visible dans l'onglet **Actions** du dépôt (un run de provisioning réussi, suivi d'un run de destruction réussi) ;
- le fichier `REFLEXION-TERRAFORM-VS-BICEP.md` à la racine, répondant aux 5 questions ci-dessus.

## Nettoyage final

En fin de TP, supprimez **toutes** vos resources :

```bash
az group list --query "[?starts_with(name, 'rg-<votre-alias>-tp104')].name" -o tsv | xargs -I {} az group delete --name {} --yes --no-wait
```
---

*Formation DevOps Azure — Simplon*
