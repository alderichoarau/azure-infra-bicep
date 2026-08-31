#!/usr/bin/env bash
# cleanup.sh - destroys ONLY the Bicep-managed resources of one exercise
# (managed_by=bicep + exercise=<exercise> tags, tracked by that exercise's
# Deployment Stack). Never touches the resource group itself, which may be
# shared across exercises, nor any resource that doesn't belong to it.
#
# Usage: ./cleanup.sh <exercise> <resource-group> [--wait] [--yes]
#   --wait : wait for deletion to complete (default: async)
#   --yes  : skip interactive confirmation (CI usage)
set -euo pipefail

EXERCISE="${1:-}"
RESOURCE_GROUP="${2:-}"
WAIT_FLAG=""
SKIP_CONFIRM=""

for arg in "${@:3}"; do
  case "$arg" in
    --wait) WAIT_FLAG="--wait" ;;
    --yes) SKIP_CONFIRM="1" ;;
  esac
done

if [[ -z "$EXERCISE" || -z "$RESOURCE_GROUP" ]]; then
  echo "Usage: $0 <ex1-vm|ex2-vmss-autoscale|ex3-appservice|ex4-container-instances|bonus-modules> <resource-group> [--wait] [--yes]"
  exit 1
fi

if ! az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
  echo "Resource group '$RESOURCE_GROUP' does not exist (or was already deleted)."
  exit 0
fi

# Same naming rule as deploy.sh: the stack name comes from the exercise.
STACK_NAME="stack-${EXERCISE}"

if ! az stack group show --name "$STACK_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
  echo "No Deployment Stack '$STACK_NAME' found in '$RESOURCE_GROUP' — nothing to destroy."
  echo "(If managed_by=bicep, exercise=$EXERCISE resources exist without a stack,"
  echo " delete them manually: az resource list --tag exercise=$EXERCISE --query \"[?resourceGroup=='$RESOURCE_GROUP']\" -o table)"
  exit 0
fi

echo ">>> Resources of '$EXERCISE' currently tracked by stack '$STACK_NAME':"
# `az resource list` rejects --tag combined with --resource-group, so filter
# by resource group client-side via --query instead.
az resource list --tag "exercise=$EXERCISE" --query "[?resourceGroup=='$RESOURCE_GROUP'].{name:name, type:type}" -o table

if [[ -z "$SKIP_CONFIRM" ]]; then
  echo ""
  echo "This will PERMANENTLY delete stack '$STACK_NAME' and every '$EXERCISE'"
  echo "resource listed above. Resource group '$RESOURCE_GROUP' and any OTHER"
  echo "exercise's/tool's resources it may contain are left untouched."
  read -rp "Confirm (type the exercise name): " CONFIRM
  if [[ "$CONFIRM" != "$EXERCISE" ]]; then
    echo "Confirmation mismatch, aborting."
    exit 1
  fi
else
  echo "Deleting stack '$STACK_NAME' in '$RESOURCE_GROUP' without confirmation (--yes)..."
fi

# --action-on-unmanage deleteAll deletes the stack AND every resource it
# manages (tagged managed_by=bicep / exercise=$EXERCISE by the template) —
# never the resource group, never another exercise's/tool's resources.
if [[ "$WAIT_FLAG" == "--wait" ]]; then
  echo ">>> Deleting stack '$STACK_NAME' (synchronous, may take a few minutes)..."
  az stack group delete \
    --name "$STACK_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --action-on-unmanage deleteAll \
    --yes
else
  echo ">>> Deleting stack '$STACK_NAME' in the background..."
  az stack group delete \
    --name "$STACK_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --action-on-unmanage deleteAll \
    --yes \
    --no-wait
fi

echo "OK."
