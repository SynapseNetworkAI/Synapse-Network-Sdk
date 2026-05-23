# Python SDK Integration

Use the Python SDK when an agent or backend service needs to discover SynapseNetwork services, invoke paid APIs, and read receipts.

## Install

```bash
pip install synapse-network-ai-sdk
```

## Create A Client

Create an Agent Key in the SynapseNetwork dashboard, then expose it to your app:

```bash
export SYNAPSE_AGENT_KEY=agt_xxx
```

```python
from synapse_client import SynapseClient

client = SynapseClient()
```

You can also pass the key explicitly:

```python
client = SynapseClient(api_key="agt_xxx", environment="prod")
```

## Search And Invoke

Always invoke fixed-price services with the price returned by discovery. This protects the caller if the provider changes price between search and execution.

```python
services = client.search("invoice extraction", limit=5)
service = services[0]

result = client.invoke(
    service.service_id,
    {"invoice_url": "https://example.com/invoice.pdf"},
    cost_usdc=str(service.price_usdc),
    idempotency_key="invoice-job-001",
)

receipt = client.get_invocation(result.invocation_id)
print(receipt.invocation_id, receipt.status, receipt.charged_usdc)
```

## Token-metered LLM Invoke

LLM services use token-metered billing. Do not pass fixed-price `cost_usdc`; pass an optional cap when you want a hard upper bound.

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
print(result.synapse.charged_usdc, result.synapse.released_usdc)
```

## Receipts

Receipts let your agent or backend tie work back to settlement evidence:

```python
receipt = client.get_invocation(result.invocation_id)

print(receipt.status)
print(receipt.charged_usdc)
print(receipt.settlement_status)
```

## Provider Publishing

If you operate an API that agents should call, continue with the [Python provider guide](./python_provider_integration.md). Consumer integrations do not need provider setup.

## Links

- SDK hub: [README](./README.md)
- PyPI: [synapse-network-ai-sdk](https://pypi.org/project/synapse-network-ai-sdk/)
- Source: [Synapse-Network-Sdk](https://github.com/SynapseNetworkAI/Synapse-Network-Sdk)
