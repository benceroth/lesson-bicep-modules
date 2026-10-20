# Blast radius: storage-v1.bicep -> storage-v2.bicep

Offline report. Regenerate with `./tests/blast-radius.ps1` (`-Check` fails if this file is stale).
It only sees callers inside this repository; callers in other repositories are why a major bump needs a migration guide.

## Contract changes

| Level | Change |
|---|---|
| major | new required parameter: costCenter |
| major | output removed or renamed: storageAccountName |
| minor | new output: name |

Required version bump: **major**

## Callers that reference `storage-v1.bicep`, re-pointed at `storage-v2.bicep`

| Caller | Result against storage-v2.bicep | Compiler codes |
|---|---|---|
| `05-breaking-change/consumer-v1.bicep` | **breaks** | BCP035, BCP083 |

1 of 1 callers break. Codes: `BCP035` = required property missing, `BCP083` = property does not exist (a renamed output).
Fix: pass the new required parameter and read the renamed output; see `05-breaking-change/MIGRATION.md`.
