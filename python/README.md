# SynapseNetwork Python SDK

Official Python SDK for agents and applications that use SynapseNetwork to discover services, invoke paid APIs, and receive auditable receipts.

## Install

```bash
pip install synapse-network-ai-sdk
```

## Quickstart

Create an Agent Key in the SynapseNetwork dashboard, then export it before your app starts:

```bash
export SYNAPSE_AGENT_KEY=agt_xxx
```

Search for a service, invoke it with the discovered price, then read the receipt:

```python
from synapse_client import SynapseClient

client = SynapseClient()

services = client.search("invoice extraction", limit=5)
service = services[0]

result = client.invoke(
    service.service_id,
    {"invoice_url": "https://example.com/invoice.pdf"},
    cost_usdc=str(service.price_usdc),
    idempotency_key="invoice-job-001",
)

receipt = client.get_invocation(result.invocation_id)
print(receipt.status, receipt.charged_usdc)
```

## Token-metered LLM Calls

LLM services use token-metered pricing. Pass an optional spend cap instead of a fixed `cost_usdc`:

```python
result = client.invoke_llm(
    "svc_deepseek_chat",
    {
        "messages": [{"role": "user", "content": "Summarize this document."}],
        "max_tokens": 512,
    },
    max_cost_usdc="0.010000",
    idempotency_key="llm-job-001",
)

print(result.usage.input_tokens, result.usage.output_tokens)
print(result.synapse.charged_usdc)
```

## Provider APIs

If you operate an API that agents should call, use the provider facade from backend or operator tooling after owner authentication. Provider setup lets you register a service, publish pricing, read health, and reconcile earnings.

Provider setup is optional for consumers. Agent runtime code usually only needs `SynapseClient`.

## Links

- SDK docs: [docs.synapse-network.ai/sdks/python](https://docs.synapse-network.ai/sdks/python)
- PyPI: [pypi.org/project/synapse-network-ai-sdk](https://pypi.org/project/synapse-network-ai-sdk/)
- Source: [github.com/SynapseNetworkAI/Synapse-Network-Sdk](https://github.com/SynapseNetworkAI/Synapse-Network-Sdk)

## License

MIT
