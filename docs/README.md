# SynapseNetwork SDK Documentation

This directory is the public documentation source for the SynapseNetwork SDK repository.

## Start Here

1. [Getting Started](./guides/getting-started.md)
2. [SDK Docs Hub](./sdk/README.md)
3. [SDK/API Parity Matrix](./sdk/api-parity-matrix.md)
4. [Quality Gates](./quality-gates.md)
5. [Agent Map](./agent-map/README.md)

## Production Environment

Public developer onboarding uses production:

- Website: `https://www.synapse-network.ai`
- SDK docs: `https://docs.synapse-network.ai/sdks`
- Gateway API: `https://api.synapse-network.ai`
- Asset: production USDC settlement through SynapseNetwork

Staging remains a sandbox for gated E2E and integration rehearsals only: `https://api-staging.synapse-network.ai` on Arbitrum Sepolia with MockUSDC.

## Contributor Notes

Run the SDK PR gate before opening a pull request:

```bash
bash scripts/ci/pr_checks.sh
```
