#!/usr/bin/env bash
# deploy.sh - deploys one exercise via a Deployment Stack, so cleanup.sh can
# later destroy exactly (and only) what this exercise created.
#
# Usage:
#   ./deploy.sh <ex1-vm|ex2-vmss-autoscale|ex3-appservice|ex4-container-instances|bonus-modules> <resource-group> [location] [--what-if]
#
# --what-if previews resource creates/changes (Bicep's equivalent of
# `terraform plan`) without deploying anything.
#
# No `set -u`: this script expands possibly-empty arrays (EXTRA_PARAMS*),
# which macOS's default bash (3.2) treats as an unbound-variable error under
# nounset even though the array is legitimately just empty.
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

EXERCISE="${1:-}"
RESOURCE_GROUP="${2:-}"
LOCATION="${3:-francecentral}"
WHAT_IF=""

for arg in "${@:4}"; do
  case "$arg" in
    --what-if) WHAT_IF="1" ;;
  esac
done

if [[ -z "$EXERCISE" || -z "$RESOURCE_GROUP" ]]; then
  echo "Usage: $0 <ex1-vm|ex2-vmss-autoscale|ex3-appservice|ex4-container-instances|bonus-modules> <resource-group> [location] [--what-if]"
  exit 1
fi

EX_DIR="$REPO_ROOT/$EXERCISE"
if [[ ! -d "$EX_DIR" ]]; then
  echo "Exercise folder not found: $EX_DIR"
  exit 1
fi

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI (az) is not installed. See https://learn.microsoft.com/cli/azure/install-azure-cli"
  exit 1
fi

echo ">>> Checking Azure CLI login..."
az account show >/dev/null || { echo "Run 'az login' first."; exit 1; }

if az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
  # Group may be pre-created and shared (e.g. rg-formateur-prf2026 in CI) —
  # don't attempt to recreate it, the CI identity may only have Contributor
  # scoped to this exact group.
  echo ">>> Resource group '$RESOURCE_GROUP' already exists, reusing it."
else
  echo ">>> Creating resource group '$RESOURCE_GROUP' in '$LOCATION'..."
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
fi

EXTRA_PARAMS=()

# ex1, ex2 and bonus deploy VMs: they need an SSH public key and the source IP
# allowed by the NSG.
if [[ "$EXERCISE" == "ex1-vm" || "$EXERCISE" == "ex2-vmss-autoscale" || "$EXERCISE" == "bonus-modules" ]]; then
  SSH_KEY_FILE=""
  for candidate in "$HOME/.ssh/id_ed25519.pub" "$HOME/.ssh/id_rsa.pub"; do
    if [[ -f "$candidate" ]]; then
      SSH_KEY_FILE="$candidate"
      break
    fi
  done
  if [[ -z "$SSH_KEY_FILE" ]]; then
    # No local key (fresh machine, or an ephemeral CI runner): generate one
    # on the fly rather than failing. Only used to satisfy adminPublicKey.
    echo "No SSH public key found in ~/.ssh/. Generating an ephemeral one..."
    EPHEMERAL_KEY="$(mktemp -u /tmp/tp-bicep-az104-XXXXXX)"
    ssh-keygen -t ed25519 -N '' -C 'tp-bicep-az104-ephemeral' -f "$EPHEMERAL_KEY" >/dev/null
    SSH_KEY_FILE="${EPHEMERAL_KEY}.pub"
  fi
  ADMIN_PUBLIC_KEY="$(cat "$SSH_KEY_FILE")"

  echo ">>> Detecting your public IP (for the NSG SSH rule)..."
  MY_IP="$(curl -s https://ifconfig.me)"
  if [[ -z "$MY_IP" ]]; then
    echo "Could not detect your public IP automatically."
    read -rp "Enter your public IP (e.g. 90.12.34.56): " MY_IP
  fi
  echo "Allowed SSH source IP: ${MY_IP}/32"

  EXTRA_PARAMS+=(adminPublicKey="$ADMIN_PUBLIC_KEY")
  EXTRA_PARAMS+=(allowedSshSourceIp="${MY_IP}/32")
fi

# Stack name is derived from the exercise, not the resource group: the group
# can be shared across exercises (e.g. rg-formateur-prf2026 in CI), so each
# exercise needs its own stack — deterministic, no state passed between
# deploy.sh / verify.sh / cleanup.sh. See README.
STACK_NAME="stack-${EXERCISE}"
DEPLOYMENT_NAME="tp104-${EXERCISE}-$(date +%Y%m%d%H%M%S)"

# Only append a second --parameters flag when there's actually something to
# override — az errors out on a --parameters flag with zero values behind it
# (which is what "${EXTRA_PARAMS[@]}" expands to for ex3/ex4, no SSH/IP needed).
EXTRA_PARAMS_FLAG=()
if [[ ${#EXTRA_PARAMS[@]} -gt 0 ]]; then
  EXTRA_PARAMS_FLAG=(--parameters "${EXTRA_PARAMS[@]}")
fi

if [[ -n "$WHAT_IF" ]]; then
  # `az stack group create` has no --what-if of its own (checked against the
  # CLI as of 2.86.0 — az stack group --help lists no such command/flag), so
  # this falls back to a plain `az deployment group what-if` against the same
  # template/parameters. It previews resource creates/changes but — unlike a
  # real stack — won't reflect --action-on-unmanage deletions.
  echo ">>> What-if preview for '$EXERCISE' (nothing will be deployed)..."
  az deployment group what-if \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$EX_DIR/main.bicep" \
    --parameters "$EX_DIR/main.parameters.json" \
    "${EXTRA_PARAMS_FLAG[@]}"
  exit 0
fi

echo ">>> Deploying '$EXERCISE' via Deployment Stack '$STACK_NAME'..."
az stack group create \
  --name "$STACK_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$EX_DIR/main.bicep" \
  --parameters "$EX_DIR/main.parameters.json" \
  "${EXTRA_PARAMS_FLAG[@]}" \
  --deny-settings-mode none \
  --action-on-unmanage deleteResources \
  --yes \
  --output json > "/tmp/${DEPLOYMENT_NAME}.json"

echo ">>> Deployment done. Outputs:"
az stack group show \
  --name "$STACK_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query properties.outputs \
  --output json

echo ""
echo "Full result saved to /tmp/${DEPLOYMENT_NAME}.json"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "resource_group=$RESOURCE_GROUP" >> "$GITHUB_OUTPUT"
fi
