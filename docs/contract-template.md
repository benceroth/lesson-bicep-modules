# Contract template

Copy this for every module you publish. A module without a filled-in contract is a parts bin
waiting to happen.

## 1. Purpose and owner

- **Capability:** one sentence (e.g. "Policy-compliant application storage").
- **Owner:** team that reviews changes.
- **Reason to change independently:** why this is its own module.

## 2. Parameters (caller-owned choices)

| Name | Type | Allowed values / constraints | Required | Why the caller decides this |
|---|---|---|---|---|
| `environment` | string | `dev`, `test`, `prod` | yes | Differs per deployment |
| `skuName` | string | `Standard_LRS`, `Standard_ZRS` | yes | Redundancy differs by environment |

Rules: every parameter has `@description` (for published modules) and the narrowest type or
`@allowed` set that is true. If a parameter has no legitimate reason to vary, it is not a parameter.

## 3. Module-owned rules (not parameters)

| Rule | Value |
|---|---|
| HTTPS only | `true` |
| Minimum TLS | `TLS1_2` |
| Public blob access | `false` |
| Deleted-blob retention | 30 days |
| Location | `westeurope` |
| Tags | `application`, `owner`, `environment` |
| Name formula | `st<environment><uniqueString(resourceGroup().id)>` |

## 4. Outputs

| Name | Type | Consumed by |
|---|---|---|
| `storageAccountId` | string | Role assignments, diagnostics |
| `storageAccountName` | string | Pipelines |

Every output is a dependency. Do not add one without a named consumer. No secrets in outputs.

## 5. Versioning policy (semver)

| Change | Bump |
|---|---|
| Remove or rename a parameter or output | **major** |
| Add a **required** parameter | **major** |
| Change a parameter or output type | **major** |
| Remove an allowed value | **major** |
| Change a module-owned rule that alters deployed resources | **major** (review with `what-if`) |
| Add an optional parameter, add an output, add an allowed value | minor |
| Internal refactor with identical deployed result (prove with `what-if`) | patch |

`tests/contract-diff.ps1` computes the parameter/output part of this table from the compiled
templates. Resource-behavior changes still need human judgement and `what-if`.

## 6. Release checklist

- [ ] `tests/validate-all.ps1` and `tests/contract-tests.ps1` pass.
- [ ] `tests/contract-diff.ps1 -Old <previous> -New <current>` agrees with the chosen bump.
- [ ] `what-if` run against a representative resource group for upgrades.
- [ ] Migration notes written for any major (see `05-breaking-change/MIGRATION.md`).
- [ ] Tag `vX.Y.Z`; consumers pin the exact version.
