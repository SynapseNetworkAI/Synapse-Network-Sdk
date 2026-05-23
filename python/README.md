# SynapseNetwork Python SDK

Official Python SDK for agents and applications that use SynapseNetwork to discover services, invoke APIs, and receive auditable USDC settlement receipts.

SynapseNetwork gives agents a scoped Agent Key instead of an unlimited API key or credit card. Your code can search for a service, invoke it with an explicit price or spend cap, then verify the receipt that records what happened.

## Install

```bash
pip install synapse-network-ai-sdk
```

Python 3.9 or newer is required.

## Five-minute quickstart

Create an Agent Key in the SynapseNetwork dashboard, then export it before your app starts:

```bash
export SYNAPSE_AGENT_KEY=agt_xxx
```

Production is the default SDK environment and uses:

```text
https://api.synapse-network.ai
```

Search for a service, invoke it with the discovered fixed price, then read the receipt:

```python
from synapse_client import SynapseClient

client = SynapseClient()

services = client.search("invoice extraction", limit=5)
service = services[0]

result = client.invoke(
    service.service_id,
    {"invoice_url": "https://example.com/invoice.pdf"},
    cost_usdc=str(service.pricing.amount),
    idempotency_key="invoice-job-001",
)

receipt = client.get_invocation(result.invocation_id)
print(receipt.status, receipt.charged_usdc)
```

## Try the free echo service

For a production connectivity smoke test, call the first-party echo service. It is intended for SDK checks and should charge `0` USDC.

```bash
python -m pip install synapse-network-ai-sdk
export SYNAPSE_AGENT_KEY=agt_xxx
```

```python
from synapse_client import SynapseClient

client = SynapseClient()

result = client.invoke(
    "svc_synapse_echo",
    {"message": "hello from the Python SDK"},
    cost_usdc="0",
    idempotency_key="python-echo-001",
)

receipt = client.get_invocation(result.invocation_id)
print(receipt.status, receipt.charged_usdc)
```

## Invocation modes

| Mode | Use for | SDK method | Billing input |
| --- | --- | --- | --- |
| Fixed-price API | Normal provider APIs with a known price | `invoke()` | Pass the latest discovered price as `cost_usdc` |
| Token-metered LLM | LLM services priced by input and output tokens | `invoke_llm()` | Pass an optional spend cap such as `max_cost_usdc` |

LLM example:

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

Most users start as consumers with `SynapseClient`. If you operate an API that agents should call, use `SynapseAuth` and the provider facade from backend or operator tooling after owner authentication.

Provider setup lets you register services, publish pricing, inspect health, and reconcile earnings. Keep normal agent runtime code on `SynapseClient` with an existing Agent Key.

## Safety rules

- Do not commit Agent Keys, owner private keys, provider secrets, wallet seed phrases, or production tokens.
- Pass money values as strings such as `"0"` or `"0.05"`; do not recompute settlement amounts with floating-point math.
- Use the discovered fixed price for `invoke()` and a spend cap for `invoke_llm()`.
- Use `gateway_url` only for private deployments or documented sandboxes. Public examples should target production.

## Links

- SDK docs: [docs.synapse-network.ai/sdks/python](https://docs.synapse-network.ai/sdks/python)
- PyPI: [pypi.org/project/synapse-network-ai-sdk](https://pypi.org/project/synapse-network-ai-sdk/)
- Source: [github.com/SynapseNetworkAI/Synapse-Network-Sdk](https://github.com/SynapseNetworkAI/Synapse-Network-Sdk)
- Issues: [github.com/SynapseNetworkAI/Synapse-Network-Sdk/issues](https://github.com/SynapseNetworkAI/Synapse-Network-Sdk/issues)

## License

MIT
