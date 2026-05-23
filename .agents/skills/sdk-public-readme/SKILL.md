# SDK Public README Checklist

Use this skill before publishing any SynapseNetwork SDK package to a public registry.

## Goal

The public README must help a new developer understand what the SDK does, install it, and complete a first call. It must not read like an internal release note, CI log, staging runbook, or bug tracker.

## Required First-screen Content

1. One sentence value proposition: agents discover services, invoke paid APIs, and receive auditable receipts.
2. Install command for the package.
3. Minimal client creation using an Agent Key.
4. Minimal service search, invoke, and receipt example.
5. Links to public docs, registry page, and source repository.

## Allowed Secondary Content

1. Token-metered LLM invocation.
2. Provider publishing as a second entry point.
3. Environment override only when clearly framed as advanced or sandbox usage.
4. Error and receipt concepts that help a developer build safely.

## Public README Must Not Contain

1. Local machine paths such as `/Users/...` or `Documents/cliff`.
2. Staging as the default onboarding path.
3. GitHub Actions, local deploy runners, publish tokens, or registry upload mechanics.
4. Bugfix indexes, internal E2E plans, or incident history.
5. Secret values, private keys, access tokens, or real production identifiers beyond public URLs.
6. Mixed English and Chinese in the same public README body.

## Validation Commands

```bash
rg "/Users/|Documents/cliff|GitHub Actions|local runner|bugfix|E2E Plan" README.md python/README.md typescript/README.md docs/sdk
cd python && python -m build && twine check dist/*
cd typescript && npm pack --dry-run
```

If the grep command returns matches in public README or docs hub files, fix the public surface before publishing. Internal operator-only docs may keep those terms when they are not linked from public package pages.
