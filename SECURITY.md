# Security policy

This repository contains sample Bicep templates, test scripts, and documentation for a fictional
company (Northstar Notes). It holds **no secrets, subscription IDs, tenant IDs, or real
registry names**. The registry name in `04-registry/bicepconfig.json` is a placeholder.

## Reporting a vulnerability

Please do not open a public issue for a security problem. Use GitHub's
**Security > Report a vulnerability** (private advisory) on this repository. Include the file,
what you observed, and the impact. You can expect an acknowledgement within a reasonable time;
this is a sample project maintained on a best-effort basis.

## If you fork and deploy

- Never commit credentials, subscription IDs, or registry credentials. Use `az login` or OIDC.
- The publish workflow uses OIDC federated credentials and repository variables, not stored secrets.
- Review `what-if` output before deploying to any shared subscription.
- These modules are examples. Enforce production guardrails with Azure Policy and RBAC as well.
