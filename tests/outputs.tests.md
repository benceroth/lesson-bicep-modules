# Output and contract expectations

What callers may rely on, and how each expectation is checked. "Offline" checks run in CI via
`tests/contract-tests.ps1`; "Live" checks need an Azure subscription and are opt-in.

## Module `02-extracted/modules/storage.bicep`

| # | Expectation | Check | Where |
|---|---|---|---|
| O1 | Exactly two outputs: `storageAccountId`, `storageAccountName` | Offline | contract-tests section 1 |
| O2 | Both outputs are `string` | Offline | `Get-Contract` in `tests/lib.ps1` / `contract-diff.ps1` |
| O3 | `storageAccountId` is the resource ID of the storage account | Offline (compiled expression is `resourceId('Microsoft.Storage/storageAccounts', ...)`) | inspect `az bicep build` output |
| O4 | `storageAccountName` equals `st<environment><uniqueString(resourceGroup().id)>` | Offline (name formula asserted) | contract-tests section 2 |
| O5 | No secrets (keys, connection strings) are output | Offline (lint rule `outputs-should-not-contain-secrets` = error) | `bicepconfig.json` |
| O6 | After deployment, the output values match the deployed account | Live | `az deployment group create ... --query properties.outputs` |

## Parent `02-extracted/main.bicep`

| # | Expectation | Check |
|---|---|---|
| P1 | Re-exposes exactly the same two outputs | Offline, contract-tests section 3 |
| P2 | Deployment name is `northstar-storage-<environment>` | Offline, contract-tests section 3 |

## Versioned change (`05-breaking-change`)

| # | Expectation | Check |
|---|---|---|
| V1 | v2 renames `storageAccountName` to `name`; `contract-diff.ps1` reports a major bump | Offline, contract-tests section 6 |
| V2 | A caller still using the old output name fails to compile against v2 | Offline, contract-tests section 6 |

## Manual live check (optional)

```powershell
az deployment group create -g <scratch-rg> -n northstar-storage-dev-v1 `
  -f 02-extracted/main.bicep -p environment=dev `
  --query properties.outputs
```

Expected shape: `storageAccountId` and `storageAccountName` with `type: String`. Names
are unique per resource group, so values differ between readers.
