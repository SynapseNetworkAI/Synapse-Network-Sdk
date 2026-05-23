<p align="center">
  <strong>English</strong> · <a href="./README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <img src="./assets/synapse-network-logo.svg" alt="SynapseNetwork logo" width="440" />
</p>

# SynapseNetwork SDK

Official SDKs for agents and applications that use SynapseNetwork to discover services, invoke paid APIs, and receive auditable receipts.

SynapseNetwork is settlement infrastructure for AI agents. Instead of giving an agent an unlimited API key or credit card, you give it a scoped Agent Key. The SDK lets that agent:

1. Search for services it is allowed to call.
2. Invoke fixed-price APIs or token-metered LLM services.
3. Read the receipt, charged amount, and settlement metadata.

## Install

| Language | Install | Registry |
| --- | --- | --- |
| Python | `pip install synapse-network-ai-sdk` | [PyPI](https://pypi.org/project/synapse-network-ai-sdk/) |
| TypeScript | `npm install @synapse-network-ai/sdk` | [npm](https://www.npmjs.com/package/@synapse-network-ai/sdk) |
| Go | `go get github.com/SynapseNetworkAI/Synapse-Network-Sdk/go@latest` | [pkg.go.dev](https://pkg.go.dev/github.com/SynapseNetworkAI/Synapse-Network-Sdk/go) |
| Java | `ai.synapse-network:synapse-network-sdk` | [Maven Central](https://repo1.maven.org/maven2/ai/synapse-network/synapse-network-sdk/) |
| .NET | `dotnet add package SynapseNetwork.Sdk` | [NuGet](https://www.nuget.org/packages/SynapseNetwork.Sdk) |

Full documentation: [docs.synapse-network.ai/sdks](https://docs.synapse-network.ai/sdks)

## First Call

Create an Agent Key in the SynapseNetwork dashboard, then pass it to the SDK as `SYNAPSE_AGENT_KEY`.

```bash
export SYNAPSE_AGENT_KEY=agt_xxx
```

### Python

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

### TypeScript

```ts
import { SynapseClient } from "@synapse-network-ai/sdk";

const client = new SynapseClient({
  credential: process.env.SYNAPSE_AGENT_KEY!,
  environment: "prod",
});

const services = await client.search("invoice extraction", { limit: 5 });
const service = services[0];

const result = await client.invoke(
  service.serviceId ?? service.id!,
  { invoice_url: "https://example.com/invoice.pdf" },
  {
    costUsdc: String(service.pricing?.amount ?? "0"),
    idempotencyKey: "invoice-job-001",
  }
);

const receipt = await client.getInvocation(result.invocationId);
console.log(receipt.status, receipt.chargedUsdc);
```

## What You Can Build

- Agent marketplaces where services expose price, schema, and health metadata.
- Agent workers that call paid APIs with scoped budgets.
- Provider APIs that meter usage and receive settlement evidence.
- Audit trails that connect a request, invocation, receipt, and final charge.

## Invocation Modes

| Mode | Use for | SDK method | Billing input |
| --- | --- | --- | --- |
| Fixed-price API | Normal provider APIs with a known price | `invoke()` / `InvokeAsync()` | Pass the latest discovered price as `cost_usdc` / `costUsdc` |
| Token-metered LLM | LLM services priced by input and output tokens | `invoke_llm()` / `invokeLlm()` | Optional spend cap such as `max_cost_usdc` / `maxCostUsdc` |

Use string money values when possible, for example `"0.05"`. Do not recompute settlement amounts with floating-point math.

## Provider Entry Point

Most users start as consumers with `SynapseClient`. If you operate an API that agents should call, use the provider facade from backend or operator tooling after owner authentication. Provider setup lets you register a service, publish pricing, read health, and reconcile earnings.

Provider setup is a second step. Keep normal agent runtime code on `SynapseClient`.

## Docs

- SDK hub: [docs.synapse-network.ai/sdks](https://docs.synapse-network.ai/sdks)
- Python guide: [docs.synapse-network.ai/sdks/python](https://docs.synapse-network.ai/sdks/python)
- TypeScript guide: [docs.synapse-network.ai/sdks/typescript](https://docs.synapse-network.ai/sdks/typescript)
- Source repository: [github.com/SynapseNetworkAI/Synapse-Network-Sdk](https://github.com/SynapseNetworkAI/Synapse-Network-Sdk)

## Environment

The public SDK default is production:

```text
https://api.synapse-network.ai
```

Use an explicit `gateway_url` / `gatewayUrl` only when you are targeting a private deployment or a documented sandbox.

## License

MIT
