# 03 - Anti-pattern: the parts bin

`modules/storage-everything.bicep` is the module you get when "make it reusable" means
"turn every property into a parameter". `main.bicep` is a caller it happily accepts.

Compare it with [`../02-extracted/modules/storage.bicep`](../02-extracted/modules/storage.bicep):

| | `02-extracted` (vending machine) | `03` (parts bin) |
|---|---|---|
| Parameters | 2 (`environment`, `skuName`) | 18 |
| Constrained with `@allowed` | both | none |
| Outputs | 2, consumed by callers | 7, mirrored "just in case" |
| Can a caller turn off HTTPS-only / TLS 1.2? | No | Yes |
| Can a caller drop the 30-day retention? | No | Yes |
| Tags guaranteed | Yes | No (`tags` defaults to `{}`) |
| Naming formula | Owned by module | Every caller invents a name |

The counts above are measured on these two files in this repo; the offline contract tests assert them.

## Review diary

A short, fictional review of the parts-bin module, in the order the questions come up.

1. **"What does this module give me that a raw resource doesn't?"** Nothing: each parameter
   maps 1:1 to a resource property. The file moved, the decisions did not.
2. **"Where is the 30-day retention rule?"** It is only a *default*. `main.bicep` here sets
   `deleteRetentionEnabled: false`; the module accepts it.
3. **"Where is TLS 1.2 enforced?"** Also a default. `minimumTlsVersion` is a plain `string`,
   so even a typo (`'TLS12'`) is only caught when Azure rejects the deployment.
4. **"Can we review a change to the SKU list?"** There is no list. `skuName` is a free string,
   so `Premium_LRS` compiles; it fails (or doesn't) in the deployment.
5. **"Who owns the tags?"** Every caller. Nothing guarantees `owner` or `environment` exist.
6. **"What breaks if we remove `provisioningState`?"** Unknown: seven outputs exist and nobody
   knows which are consumed.
7. **Verdict: rejected.** Callers can weaken security, and a policy change would need a
   change in every caller. The module adds a nested deployment without adding encapsulation.

Run `pwsh ../tests/contract-tests.ps1` to see this demonstrated: the weak caller compiles
here, while the equivalent values are rejected by the real contract.
