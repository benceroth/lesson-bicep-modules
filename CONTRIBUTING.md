# Contributing

Small, focused changes are welcome.

1. Install Azure CLI and the pinned Bicep version: `az bicep install --version (Get-Content .bicep-version)`.
2. Make your change.
3. Run the same checks CI runs:
   ```powershell
   ./tests/validate-all.ps1
   ./tests/contract-tests.ps1
   ./tests/what-if-equivalence.ps1
   ```
4. If you change a module's parameters or outputs, record the semver impact in your pull
   request using `./tests/contract-diff.ps1` (see `docs/contract-template.md`).
5. If a change alters the reports in `evidence/`, regenerate them with
   `./tests/compare-before-after.ps1` and `./tests/blast-radius.ps1`.
6. No secrets, real subscription IDs, or real registry names in any file.

Intentional exceptions: `03-anti-pattern-parts-bin` and `break-it/` are deliberately bad and `tests/fixtures`
contains files that are expected not to compile. Please don't "fix" them.
