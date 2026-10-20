# Migrating `storage` from 1.x to 2.0.0

Files: [`storage-v1.bicep`](./storage-v1.bicep), [`storage-v2.bicep`](./storage-v2.bicep),
[`consumer-v1.bicep`](./consumer-v1.bicep), [`consumer-v2.bicep`](./consumer-v2.bicep).

## Why this is a major version

Per [`docs/contract-template.md`](../docs/contract-template.md), any rename or removal of a
parameter or output, and any new required parameter, is a **major** change.

| Change | v1.0.0 | v2.0.0 | Effect on callers |
|---|---|---|---|
| New required parameter | - | `costCenter` | Compile error: missing required property |
| Output renamed | `storageAccountName` | `name` | Compile error: output does not exist |
| Output unchanged | `storageAccountId` | `storageAccountId` | None |
| Deployed policy (HTTPS, TLS 1.2, retention, location) | same | same | None |
| New tag | - | `costCenter` | Tag added on update |

`tests/contract-diff.ps1` computes this table from the compiled templates and recommends the
bump, so the version number is derived from the contract, not from mood.

## Migration steps

1. Pin to the old version first (`storage-v1.bicep`, or `br/northstar:storage:1.x.y`) and keep deploying.
2. In a branch, switch the module reference to v2.
3. Add `costCenter` to the `params` block.
4. Replace `storage.outputs.storageAccountName` with `storage.outputs.name`.
5. Run `az bicep build` (offline) - both mistakes above are compile errors, not runtime surprises.
6. Run `az deployment group what-if` against the target resource group. Expected: the
   `costCenter` tag is added (a `Modify`); nothing else changes.
7. Deploy through your normal pipeline and then update documentation/pins.

## Rollback

Re-pin the caller to v1 and redeploy. The template declares the full `tags` object, so the
redeploy should drop the `costCenter` tag again; confirm with `what-if` first.

## Tested here

`tests/contract-tests.ps1` verifies offline that: `consumer-v1` and `consumer-v2` compile; an
un-migrated caller (`tests/fixtures/consumer-unmigrated-v2.bicep`) does not; and the contract
diff classifies v1 -> v2 as `major`. The `what-if` in step 6 requires a subscription and is
not run in CI.
