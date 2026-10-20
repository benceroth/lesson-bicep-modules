# Refactor comparison: flat vs module

Measured on the files in this repo (Bicep v0.45.15). Offline; nothing is deployed.
Regenerate with `./tests/compare-before-after.ps1` (`-Check` fails if this file is stale).

## Measured

| Version | Files | Code lines | Deployed resources | Parent params | Module params | Module params with @allowed | Module outputs | Policy lines |
|---|---|---|---|---|---|---|---|---|
| 01 flat | 1 | 38 | 2 | 1 | 0 | 0 | 0 | 5 |
| 02 module | 2 | 58 | 2 | 1 | 2 | 2 | 2 | 5 |
| 03 parts bin | 2 | 74 | 2 | 0 | 18 | 0 | 7 | - |

- *Code lines*: non-blank lines that are not comment-only, across the files listed for that version.
- *Deployed resources*: resources in the compiled template, including those inside the module; 01 and 02 deploy the same ones.
- *Policy lines*: lines setting HTTPS-only, TLS, public blob access or retention. Not counted for 03, where they are parameters with defaults.
- Rows 01 and 02 deploy identical resources (see `./tests/what-if-equivalence.ps1`). The module is not shorter; its value is the narrower surface callers see: 2 module parameters instead of 18.

## Projection (arithmetic on the numbers above, not a measurement)

| Scenario | Policy lines to keep in sync |
|---|---|
| Flat template copied for 3 environments | 15 (5 x 3) |
| One shared module used by 3 environments | 5 |

The 3-copy row assumes a team copies the flat file per environment. The repo does not contain such copies.
