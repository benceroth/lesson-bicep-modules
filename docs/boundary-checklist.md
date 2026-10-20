# Boundary checklist

Use before extracting a module. If you cannot answer these, don't extract yet.

## Ownership
- [ ] Which team reviews changes to this capability?
- [ ] Is that team different from the callers? (If not, a local folder may be enough.)

## Lifecycle
- [ ] Are the resources always created, updated, and deleted together?
- [ ] Do they share a deployment scope (resource group, subscription)?
- Northstar: storage account + blob service retention policy: yes, one module.

## Change rate
- [ ] Does it change at a different pace than its neighbors (e.g. security defaults vs app settings)?
- [ ] Would a change need the author to understand unrelated resources? That is coupling; split.

## What varies
- [ ] List every property that differs between callers. Those are candidate parameters.
- [ ] List every property that must never differ. Those are module-owned rules.
- [ ] Anything on neither list? Decide now; don't default to "make it a parameter".

## Interface size
- [ ] Parameters can be explained in one sentence each, and most are constrained.
- [ ] Every output has a named consumer.
- [ ] Callers cannot weaken a security control through a parameter.

## Smells
- Module per resource with no policy inside.
- Parameters that mirror resource properties 1:1.
- Outputs "just in case".
- Hard-coded resource IDs passed between modules instead of symbolic outputs.
- Needing `dependsOn` where an output reference would express the relationship.

## Local path or registry?
- Local path: one repo, caller and module evolve together.
- Registry: two or more repos consume it and you can commit to semver and migration notes.
