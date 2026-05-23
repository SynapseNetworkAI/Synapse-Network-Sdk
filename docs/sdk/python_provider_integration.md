# Python Provider Integration

Use the provider facade when you operate an API that should be discoverable and callable by agents through SynapseNetwork.

Most users should start with `SynapseClient`. This guide is for provider teams that want to publish a service.

## Install

```bash
pip install synapse-network-ai-sdk
```

## Authenticate As The Owner

Provider publishing is owner-scoped. Authenticate with the wallet that owns the provider account from backend or operator tooling, then create the provider facade:

```python
from synapse_client import SynapseAuth

owner_signing_key = load_owner_signing_key_from_your_backend()
auth = SynapseAuth.from_private_key(owner_signing_key, environment="prod")
provider = auth.provider()
```

Keep owner signing material out of browser and agent runtime code.

## Register A Service

Expose a public HTTPS endpoint, describe what the service does, and set the price agents should see during discovery.

```python
registered = provider.register_service(
    service_name="Invoice OCR",
    endpoint_url="https://provider.example.com/invoke",
    base_price_usdc="0.008",
    description_for_model="Extract structured invoice fields from invoice images.",
)

print(registered.service_id)
```

SynapseNetwork uses your service metadata for discovery, invocation routing, metering, and receipt generation.

## Check Service Status

```python
status = provider.get_service_status(registered.service_id)

print(status.lifecycle_status)
print(status.health.overall_status)
print(status.runtime_available)
```

## Token-metered LLM Services

For LLM endpoints, register token prices instead of a fixed base price:

```python
llm = provider.register_llm_service(
    service_name="DeepSeek Chat",
    service_id="svc_deepseek_chat",
    endpoint_url="https://provider.example.com/llm/deepseek-chat",
    description_for_model="OpenAI-compatible chat completion endpoint.",
    input_price_per_1m_tokens_usdc="0.140000",
    output_price_per_1m_tokens_usdc="0.280000",
    default_max_output_tokens=2048,
    max_auto_hold_usdc="0.050000",
)

print(llm.service_id)
```

## Provider Operations

The provider facade also supports:

- Provider secret issuance and rotation.
- Service list, read, update, delete, ping, and health history.
- Earnings summary and withdrawal helpers.

Keep provider code separate from normal agent runtime code. Agents calling your API should use `SynapseClient`.

## Links

- Python consumer guide: [python_integration.md](./python_integration.md)
- SDK hub: [README](./README.md)
- PyPI: [synapse-network-ai-sdk](https://pypi.org/project/synapse-network-ai-sdk/)
