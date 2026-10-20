# 04 - Registry module (opt-in)

Local paths are right while a module and its caller evolve together. Publish when a second
repository needs the same capability.

1. Create a private ACR (outside this repo) and note its name.
2. Edit `bicepconfig.json`: set `moduleAliases.br.northstar.registry` to `<name>.azurecr.io`.
3. Publish: `./publish.ps1 -RegistryName <name> -Version 1.0.0` (or `./publish.sh <name> 1.0.0`).
   Add `-WhatIf` to see the target without publishing.
4. Consume: `consumer/main.bicep` references `br/northstar:storage:1.0.0` and pins the version.
5. Upgrade deliberately: change the version, run `what-if`, review, deploy.

The alias resolves to `br:<registry>/bicep/modules/storage:<version>`.

This folder is excluded from offline CI because restoring `br/` modules needs a registry
(and `az bicep restore`/`build` on the consumer would fail without one). The publish script's
module source is compiled in CI, so it never publishes something that does not build.
