# Release Checklist

Use this checklist for SDK releases and public documentation updates.

## Preflight

- [ ] `bash scripts/ci/pr_checks.sh` passes.
- [ ] Read `docs/ops/sdk-release-runbook.md`.
- [ ] `.github/workflows/ci.yml` and `.github/workflows/pr-ci.yml` are current.
- [ ] 更新 CHANGELOG.md with the release date and developer-visible changes.
- [ ] Public examples use `SYNAPSE_AGENT_KEY`.
- [ ] Public examples use `SYNAPSE_ENV=prod` or omit the variable because prod is the SDK default.
- [ ] Fixed-price examples pass string money from discovery.
- [ ] Token-metered LLM examples use `invoke_llm()` / `invokeLlm()` without fixed `cost_usdc` / `costUsdc`.
- [ ] Public owner/provider returns are named SDK models/interfaces, not raw maps.

## Staging Sandbox Verification

- [ ] Staging gateway health is verified.
- [ ] Arbitrum Sepolia and MockUSDC language is current.
- [ ] One fixed-price staging invoke is verified.
- [ ] One token-metered LLM staging invoke is verified when a staging LLM service is available.
- [ ] Receipt lookup is verified.

## Production Verification

- [ ] Production gateway health is verified at `https://api.synapse-network.ai/health`.
- [ ] Production docs are verified at `https://docs.synapse-network.ai/sdks`.
- [ ] Production website is verified at `https://www.synapse-network.ai`.
- [ ] Public examples and docs are prod-first; staging appears only as sandbox/E2E guidance.

## Publish

- [ ] Initialize the SDK release train in Synapse-Network-Growing `/releases` -> `SDK Packages`.
- [ ] Dry-run each selected package through `.github/workflows/publish-sdk.yml`.
- [ ] Publish each selected package through `.github/workflows/publish-sdk.yml`.
- [ ] For Go, verify the subdirectory module tag uses `go/vX.Y.Z`.
- [ ] Publish the GitHub Release with package URLs, install notes, and production status.
- [ ] Do not describe SDK packages as staging/prod deployments; SDK packages only have registry channels.
