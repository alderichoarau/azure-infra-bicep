#!/usr/bin/env bash
# verify.sh - functional check of an already-deployed exercise. Used locally
# and by bicep-provision.yml. Exits non-zero on failure.
#
# Usage: ./verify.sh <exercise> <resource-group>
set -uo pipefail

EXERCISE="${1:-}"
RESOURCE_GROUP="${2:-}"

if [[ -z "$EXERCISE" || -z "$RESOURCE_GROUP" ]]; then
  echo "Usage: $0 <exercise> <resource-group>"
  exit 1
fi

# Same naming rule as deploy.sh: the stack name comes from the exercise, not
# the resource group (which can be shared across exercises).
STACK_NAME="stack-${EXERCISE}"

OUTPUTS_JSON="$(az stack group show \
  --name "$STACK_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query properties.outputs \
  --output json)"

echo ">>> Deployment outputs (stack '$STACK_NAME'):"
echo "$OUTPUTS_JSON" | jq .

# curl_with_retries <url> <max-attempts> <delay-seconds>
# CustomScript extensions (VM/VMSS) and container startup take a bit of time
# after the ARM deployment completes, hence the retries.
curl_with_retries() {
  local url="$1"
  local attempts="${2:-10}"
  local delay="${3:-30}"
  local i
  for ((i = 1; i <= attempts; i++)); do
    echo "  attempt $i/$attempts: curl $url"
    if curl -fsS --max-time 10 "$url" >/tmp/verify-curl-output.txt 2>/tmp/verify-curl-error.txt; then
      echo "  OK, response excerpt:"
      head -c 300 /tmp/verify-curl-output.txt
      echo ""
      return 0
    fi
    sleep "$delay"
  done
  echo "  FAILED after $attempts attempts:"
  cat /tmp/verify-curl-error.txt
  return 1
}

case "$EXERCISE" in
  ex1-vm)
    IP="$(echo "$OUTPUTS_JSON" | jq -r '.publicIpAddress.value')"
    echo ">>> Checking HTTP on the VM ($IP), the CustomScript extension can take 1-2 min..."
    curl_with_retries "http://$IP" 10 20
    ;;

  ex2-vmss-autoscale)
    FQDN="$(echo "$OUTPUTS_JSON" | jq -r '.loadBalancerFqdn.value')"
    echo ">>> Checking HTTP via the Load Balancer ($FQDN)..."
    curl_with_retries "http://$FQDN" 10 20
    ;;

  ex3-appservice)
    URL="$(echo "$OUTPUTS_JSON" | jq -r '.webAppUrl.value')"
    STAGING_URL="$(echo "$OUTPUTS_JSON" | jq -r '.stagingSlotUrl.value')"
    echo ">>> Checking HTTPS on the production Web App ($URL)..."
    curl_with_retries "$URL" 10 15 || exit 1
    echo ">>> Checking HTTPS on the staging slot ($STAGING_URL)..."
    curl_with_retries "$STAGING_URL" 10 15
    ;;

  ex4-container-instances)
    FQDN="$(echo "$OUTPUTS_JSON" | jq -r '.containerGroupFqdn.value')"
    echo ">>> Checking HTTP on the container group ($FQDN)..."
    curl_with_retries "http://$FQDN" 10 15
    ;;

  bonus-modules)
    IP="$(echo "$OUTPUTS_JSON" | jq -r '.vmPublicIps.value[0]')"
    echo ">>> Checking HTTP on the module's first VM ($IP)..."
    curl_with_retries "http://$IP" 10 20
    ;;

  *)
    echo "Unknown exercise for verification: $EXERCISE"
    exit 1
    ;;
esac
