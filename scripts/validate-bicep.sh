#!/usr/bin/env bash
# validate-bicep.sh - compiles every Bicep template without deploying, to
# catch syntax/type errors early. Works with 'az bicep build' or standalone 'bicep'.
#
# Usage: ./validate-bicep.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

if command -v az >/dev/null 2>&1; then
  BICEP_CMD=(az bicep build --file)
elif command -v bicep >/dev/null 2>&1; then
  BICEP_CMD=(bicep build)
else
  echo "Neither 'az' nor 'bicep' is installed. See https://learn.microsoft.com/azure/azure-resource-manager/bicep/install"
  exit 1
fi

FAIL=0
while IFS= read -r -d '' file; do
  echo -n "Building ${file#$REPO_ROOT/} ... "
  if "${BICEP_CMD[@]}" "$file" --outfile /tmp/bicep-validate-out.json 2>/tmp/bicep-validate-err.log; then
    echo "OK"
  else
    echo "FAILED"
    cat /tmp/bicep-validate-err.log
    FAIL=1
  fi
done < <(find "$REPO_ROOT" -name "*.bicep" -not -path "*/modules/*" -print0)

echo ""
echo "--- Modules (only built via the main.bicep that references them) ---"
# -printf is a GNU find extension (unavailable on macOS's BSD find), so stick
# to a plain find + loop for portability.
while IFS= read -r module_file; do
  echo "${module_file#$REPO_ROOT/}"
done < <(find "$REPO_ROOT" -path "*/modules/*.bicep")

if [[ $FAIL -eq 0 ]]; then
  echo ""
  echo "All templates compiled successfully."
else
  echo ""
  echo "At least one template failed to compile, see above."
  exit 1
fi
