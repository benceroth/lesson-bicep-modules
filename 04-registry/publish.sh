#!/usr/bin/env bash
# Opt-in: publishes 02-extracted/modules/storage.bicep to a private Azure Container Registry.
# Requires: az login, an existing ACR, and push permission (AcrPush role).
# Usage: ./publish.sh <registry-name> <version>   e.g. ./publish.sh myacr 1.0.0
set -euo pipefail

registry="${1:?registry name required}"
version="${2:?version required (x.y.z)}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "version must be x.y.z" >&2; exit 1; }

here="$(cd "$(dirname "$0")" && pwd)"
file="$here/../02-extracted/modules/storage.bicep"
target="br:${registry}.azurecr.io/bicep/modules/storage:${version}"

az bicep build --file "$file" --stdout > /dev/null
az bicep publish --file "$file" --target "$target"
echo "Published $target"
