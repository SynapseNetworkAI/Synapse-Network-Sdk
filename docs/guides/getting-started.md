# Getting Started

Use this guide to connect the SDK to production.

## Environment

Production is the default public integration path:

- Website: `https://www.synapse-network.ai`
- SDK docs: `https://docs.synapse-network.ai/sdks`
- Gateway API: `https://api.synapse-network.ai`
- Asset: production USDC settlement through SynapseNetwork

Set:

```bash
export SYNAPSE_ENV=prod
export SYNAPSE_AGENT_KEY=agt_xxx
```

Staging remains available only as a sandbox/E2E target: `https://api-staging.synapse-network.ai` on Arbitrum Sepolia with MockUSDC.

## Choose an Integration Path

| Goal | Use |
|---|---|
| Connect an agent framework such as Cursor, Claude Desktop, or LangChain | `@synapse-network-ai/mcp-server` |
| Write application code that invokes services directly | `SynapseClient` |
| Issue agent credentials or manage provider services | `SynapseAuth` and `auth.provider()` |

## Fixed-Price API Invoke

Use fixed-price invoke for normal API services. Pass the latest discovery price through as a string.

```python
from synapse_client import SynapseClient

client = SynapseClient()
service = client.search("sentiment", limit=1)[0]

result = client.invoke(
    service.service_id,
    {"target": "Ethereum"},
    cost_usdc=str(service.price_usdc),
    idempotency_key="agent-job-001",
)

print(result.invocation_id, result.charged_usdc)
```

## Token-Metered LLM Invoke

Use LLM invoke for services registered as token-metered LLMs. Do not send `cost_usdc` / `costUsdc`; pass an optional maximum spend cap instead.

```python
from synapse_client import SynapseClient

client = SynapseClient()

result = client.invoke_llm(
    "svc_provider_deepseek_chat",
    {"messages": [{"role": "user", "content": "Hello"}]},
    max_cost_usdc="0.10",
    idempotency_key="agent-job-002",
)

print(result.usage, result.synapse)
```

## Validation

Before contributing SDK changes, run:

```bash
bash scripts/ci/pr_checks.sh
```
