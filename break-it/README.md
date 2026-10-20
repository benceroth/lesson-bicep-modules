# Break it

Four deliberate failures. Each one is a real mistake from the post, shown failing the way it would
for your team. Run them all offline (no Azure login):

```powershell
./break-it/run.ps1
```

A scenario "passes" when the expected failure is observed. Nothing here is imported by the real
templates, and `tests/validate-all.ps1` does not build these files.

| # | Scenario | Who catches it | Fix |
|---|---|---|---|
| [1](./01-contract-violation/) | Pass an environment that is not in the contract | Bicep compiler (`BCP033`) | Use `dev`, `test` or `prod` |
| [2](./02-leak-a-parameter/) | Expose `minimumTlsVersion` as a parameter | Nobody at compile time; the contract diff does | Keep policy as a literal inside the module |
| [3](./03-unmigrated-caller/) | Point a v1 caller at module v2 | Bicep compiler (`BCP035`, `BCP083`) | Follow `05-breaking-change/MIGRATION.md` |
| [4](./04-silent-drift/) | Change retention from 30 to 31 days inside the module | `what-if-equivalence.ps1` | Revert, or change the baseline on purpose |

## 1. Contract violation

```powershell
az bicep build-params --file break-it/01-contract-violation/dev-staging.bicepparam --stdout
```

Expected: `Error BCP033: Expected a value of type "'dev' | 'prod' | 'test'" but the provided value is of type "'staging'".`

Fix: `param environment = 'dev'`. The `@allowed` list is the contract; to add an environment, change the module and the parent together, and treat it as a minor version.

## 2. Leaking a parameter

`02-leak-a-parameter/storage.bicep` adds `param minimumTlsVersion string = 'TLS1_2'`, and `main.bicep` uses it to deploy TLS 1.0. Both compile, which is the point: a leaked parameter is a valid Bicep file.

```powershell
./tests/contract-diff.ps1 -Old 02-extracted/modules/storage.bicep -New break-it/02-leak-a-parameter/storage.bicep
```

Expected: `[minor] new optional parameter: minimumTlsVersion`. `./tests/contract-tests.ps1` also fails its "exactly two parameters" check if you swap this module in.

Fix: delete the parameter and restore the literal `minimumTlsVersion: 'TLS1_2'`.

## 3. Un-migrated caller

```powershell
az bicep build --file break-it/03-unmigrated-caller/consumer.bicep
```

Expected: `BCP035` (missing required `costCenter`) and `BCP083` (output `storageAccountName` no longer exists).

Fix: pass `costCenter` and read `storage.outputs.name`; see [`05-breaking-change/MIGRATION.md`](../05-breaking-change/MIGRATION.md).

## 4. Silent drift

`04-silent-drift/storage.bicep` keeps deleted blobs for 31 days. Every file compiles and lints cleanly.

```powershell
./tests/what-if-equivalence.ps1 -Candidate break-it/04-silent-drift/main.bicep
```

Expected: `FAIL  identical resolved definition: Microsoft.Storage/storageAccounts/blobServices|...` showing `days: 30` against `days: 31`.

Fix: restore `days: 30`. If the new value is intended, that is a deliberate policy change: update the baseline and the contract tests in the same pull request.
