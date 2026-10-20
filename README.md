# lesson-bicep-modules

[![validate](https://github.com/benceroth/lesson-bicep-modules/actions/workflows/validate.yml/badge.svg)](https://github.com/benceroth/lesson-bicep-modules/actions/workflows/validate.yml)

**The question this repo answers:** when you split a Bicep template into modules, what should the
module let callers decide, and what should it keep to itself?

**After working through it you can:** extract a module from a flat template and prove nothing
deployed changed, design a small policy-aware parameter/output contract, tell a good module from a
"parts bin", and version a breaking change without surprising consumers.

Companion code for the story *Scale Bicep With Modules Without Building a Monolith* ([read it on Medium](https://medium.com/@benceroth/scaling-infrastructure-with-bicep-modules-bb7dc9f9ccf6)).
Prerequisite: the first-deployment repo, [`lesson-bicep-first-deployment`](https://github.com/benceroth/lesson-bicep-first-deployment). Next: [`lesson-bicep-private-storage`](https://github.com/benceroth/lesson-bicep-private-storage).

> Fictional scenario: Northstar Notes needs the same policy-compliant storage in `rg-northstar-dev`,
> `rg-northstar-test`, and `rg-northstar-prod` (`westeurope`). Only the environment and the SKU vary.

## Run it in a few minutes (no Azure login, no cost)

Requires Azure CLI and PowerShell 7 (Windows PowerShell 5.1 also works). Install Bicep with
`az bicep install --version (Get-Content .bicep-version)`.

```powershell
./tests/validate-all.ps1          # build + lint every template; fails on any warning
./tests/contract-tests.ps1        # contract, owned settings, bad inputs rejected, v1 -> v2
./tests/what-if-equivalence.ps1   # 01 and 02 deploy identical resources (offline)
./tests/contract-diff.ps1 -Old 05-breaking-change/storage-v1.bicep -New 05-breaking-change/storage-v2.bicep
./break-it/run.ps1                # four deliberate failures, each caught as documented
```

CI (`.github/workflows/validate.yml`) runs the first four commands; `validate-all.ps1` also runs `break-it/run.ps1` and checks that the committed reports in [`evidence/`](./evidence/) are current.

## The tags are the steps

The history is one commit per step of the post. Browse a step at `tree/step-N` or compare two:

| Tag | Post step | What it adds |
|---|---|---|
| [`step-1`](https://github.com/benceroth/lesson-bicep-modules/tree/step-1) | 1. Define the boundary | The flat baseline and the [boundary checklist](./docs/boundary-checklist.md) |
| [`step-2`](https://github.com/benceroth/lesson-bicep-modules/tree/step-2) | 2. Define the contract | The [contract template](./docs/contract-template.md) and the contract-diff tool |
| [`step-3`](https://github.com/benceroth/lesson-bicep-modules/tree/step-3) | 3. Implement the module | `02-extracted/modules/storage.bicep` |
| [`step-4`](https://github.com/benceroth/lesson-bicep-modules/tree/step-4) | 4. Wire the parent | `02-extracted/main.bicep` and the parameter files |
| [`step-5`](https://github.com/benceroth/lesson-bicep-modules/tree/step-5) | 5. Preview and deploy | The offline equivalence test |

The before/after of the refactor is [`step-1...step-4`](https://github.com/benceroth/lesson-bicep-modules/compare/step-1...step-4). Later commits add the examples, evidence and failure scenarios on `main`.

## The folders

| Folder | What it is |
|---|---|
| [`01-flat-baseline`](./01-flat-baseline/main.bicep) | The "before": one flat file |
| [`02-extracted`](./02-extracted/) | The post's end state: `main.bicep`, `modules/storage.bicep`, `params/{dev,test,prod}.bicepparam` |
| [`03-anti-pattern-parts-bin`](./03-anti-pattern-parts-bin/) | A module that exposes every property, and a review diary on why it fails |
| [`04-registry`](./04-registry/) | Publish to a private ACR and consume `br/northstar:storage:1.0.0` (opt-in) |
| [`05-breaking-change`](./05-breaking-change/MIGRATION.md) | v1 -> v2 (new required parameter, renamed output) and a migration guide |
| [`break-it`](./break-it/README.md) | Four deliberate failures with expected errors and fixes |
| [`evidence`](./evidence/) | Generated reports: [flat vs module](./evidence/refactor-comparison.md), [breaking-change blast radius](./evidence/blast-radius.md) |
| [`tests`](./tests/) | Contract tests, equivalence test, contract diff, report generators |
| [`docs`](./docs/) | [Boundary checklist](./docs/boundary-checklist.md), [contract template](./docs/contract-template.md) |

## What the tests prove

- **Contract:** the module has exactly two parameters (`environment`, `skuName`), constrained with
  `@allowed`, and two outputs. HTTPS-only, TLS 1.2, no public blob access, 30-day retention,
  location and tags are literals inside the module.
- **Bad inputs fail:** `environment=staging`, `skuName=Premium_LRS`, and trying to pass
  `minimumTlsVersion` are all rejected by the Bicep compiler (checked offline), and the compiled ARM
  template keeps `allowedValues` so ARM rejects the same values at deployment.
- **Refactor is safe:** `what-if-equivalence.ps1` compiles 01 and 02, resolves variables and
  parameters across the module boundary, and compares every deployed resource. Mutating the module
  (e.g. retention 30 -> 31) makes it fail.
- **Contrast:** the parts-bin module has 18 parameters (none constrained) and 7 outputs, and a caller
  that disables HTTPS-only, uses TLS 1.0, opens public blob access, drops retention and omits all tags
  compiles cleanly. These counts are measured on the files in this repo.
- **Versioning:** `contract-diff.ps1` classifies v1 -> v2 as a **major** change; an un-migrated
  caller fails to compile against v2.

## Evidence you can regenerate

```powershell
./tests/compare-before-after.ps1   # writes evidence/refactor-comparison.md
./tests/blast-radius.ps1          # writes evidence/blast-radius.md
```n
Both are offline and deterministic. The first measures line counts and parameter surface of 01, 02 and 03; its three-copy row is labelled as a projection, not a measurement. The second re-points every caller of v1 at v2 and reports which break.

## Extend it

1. **Add an approved SKU.** Add `Standard_GRS` to `skuName` in the module. Run `contract-diff.ps1` against the old file and confirm it asks for a *minor* bump, then decide whether `main.bicep` should ever select it.
2. **Add an output.** Return `primaryBlobEndpoint` from the module and the parent. Update `contract-tests.ps1` so it expects three outputs, and write down in the [contract template](./docs/contract-template.md) who will consume it.
3. **Write your own break-it.** Make retention a parameter in a copy of the module, add it as a fifth scenario in `break-it/`, and have `break-it/run.ps1` prove which check catches it.

## Opt-in live paths

| What | How | Needs |
|---|---|---|
| Real what-if equivalence | `./tests/what-if-equivalence.ps1 -Live -ResourceGroup <scratch-rg>` | `az login`, an existing scratch resource group (creates one storage account) |
| ARM-side validation of bad inputs | `./tests/contract-tests.ps1 -Live -ResourceGroup <scratch-rg>` | `az login` |
| Publish and consume from a registry | See [`04-registry`](./04-registry/README.md) | An ACR you own |

Manual deploy of one environment, as in the post:

```bash
az bicep build --file 02-extracted/main.bicep
az deployment group what-if -g rg-northstar-dev -f 02-extracted/main.bicep -p environment=dev
az deployment group create -n northstar-storage-dev-v1 -g rg-northstar-dev -f 02-extracted/main.bicep -p environment=dev
```

## Known limits

- The offline equivalence test compares compiled, resolved templates. It does not ask Azure; the live
  `-Live` mode does. Neither covers drift in existing resources.
- Offline tests cannot show how Azure Resource Manager or Azure Policy will respond; only live runs do.
  Modules are not a substitute for Azure Policy or RBAC.
- Registry publishing/restoring (`04-registry`) is not exercised in CI. Its alias points at a
  placeholder registry (`northstarexample.azurecr.io`).
- The module hard-codes `westeurope` and the tag values because that is the post's contract; a real
  platform module would likely parameterize more deliberately.
- The post's "illustrative comparison" (three copied blocks vs. one module) is not measured here.
  The repo only measures the contrast it contains (see above).
- `@description` and user-defined types are recommended in the post but left out of the module so
  the code matches the post; the [contract template](./docs/contract-template.md) shows what to document.
- Tested with Bicep CLI 0.45.15 (pinned in `.bicep-version`).

## License

[MIT](./LICENSE). See also [SECURITY.md](./SECURITY.md) and [CONTRIBUTING.md](./CONTRIBUTING.md).

<sub>[Bence Roth](https://broth.hu/)</sub>
