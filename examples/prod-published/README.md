# Published SDK Production Free Invoke

These examples verify that the public SDK packages can talk to the production
Gateway at `https://api.synapse-network.ai` without using local source code.

The smoke flow is intentionally free-only:

1. Create a local test owner wallet.
2. Authenticate the owner wallet with production.
3. Issue a short-lived Agent Key.
4. Discover a zero-price production service.
5. Assert the service is fixed-price and costs `0`.
6. Invoke the service and fetch the receipt.
7. Assert `chargedUsdc` is zero.

The test wallet is not funded and must only be used for free production
services. Do not add funds to this wallet unless you intentionally want a paid
production smoke account.

## Packages

| SDK | Published package | Version |
| --- | --- | --- |
| Python | `synapse-network-ai-sdk` | `1.0.0` |
| TypeScript | `@synapse-network-ai/sdk` | `1.0.0` |
| Go | `github.com/SynapseNetworkAI/Synapse-Network-Sdk/go` | `v1.0.0` |
| .NET | `SynapseNetwork.Sdk` | `1.0.0` |
| Java | `ai.synapse-network:synapse-network-sdk` | `1.0.0` |

Java is handled as a strict published-package gate. The runner verifies Maven
Central serves `ai.synapse-network:synapse-network-sdk:1.0.0` and does not fall
back to this repository's source.

## Setup

Generate a fresh local test wallet and write it to a controlled block in
`~/.zshrc`:

```bash
bash examples/prod-published/scripts/setup-prod-test-wallet.sh
source ~/.zshrc
```

The setup script prints the address but never prints the full private key. The
private key is stored only in your local shell profile as
`SYNAPSE_PROD_TEST_OWNER_PRIVATE_KEY`.

To replace the wallet later:

```bash
bash examples/prod-published/scripts/setup-prod-test-wallet.sh --force
source ~/.zshrc
```

## Run

```bash
bash examples/prod-published/scripts/run-all.sh
```

Outputs are written under ignored local state:

- `output/prod-published-sdk/report.json`
- `output/prod-published-sdk/logs/`
- `output/prod-published-sdk/work/`

The report is redacted and contains only package, service, invocation, receipt,
charge, and blocker status. It never includes private keys, Agent Keys, JWTs, or
authorization headers.

## Environment

The runner defaults to production:

```bash
export SYNAPSE_ENV=prod
export SYNAPSE_GATEWAY_URL=https://api.synapse-network.ai
```

Optional overrides:

```bash
export SYNAPSE_PROD_FREE_SERVICE_ID=svc_oss_security_healthcheck
export SYNAPSE_PROD_PUBLISHED_WORK_DIR=output/prod-published-sdk
```

Do not set paid service IDs for this smoke. The runner rejects non-zero fixed
prices before invoking.

The runner defaults to `svc_oss_security_healthcheck` because it is currently
published in production as a zero-price fixed API. If `svc_synapse_echo` is
published later, set `SYNAPSE_PROD_FREE_SERVICE_ID=svc_synapse_echo`.
