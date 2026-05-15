# Support

## Production Support

The SDK is currently documented for production:

- Website: `https://www.synapse-network.ai`
- SDK docs: `https://docs.synapse-network.ai/sdks`
- Gateway API: `https://api.synapse-network.ai`

Staging remains available only as a sandbox/E2E target: `https://api-staging.synapse-network.ai` on Arbitrum Sepolia with MockUSDC.

## Before Opening an Issue

Please include:

- SDK language and version.
- Whether you are using fixed-price `invoke()` / `invoke` or token-metered `invoke_llm()` / `invokeLlm()`.
- Gateway environment, normally `prod`.
- Request ID and idempotency key if an invocation failed.
- Redacted error payloads and stack traces.

Never paste private keys, seed phrases, real credentials, or production tokens.

## Security Reports

Use `SECURITY.md` for vulnerability reports or credential exposure concerns.
