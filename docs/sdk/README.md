<p align="center">
  <strong>English</strong> · <a href="./README.zh-CN.md">简体中文</a>
</p>

# SynapseNetwork SDK Hub

SynapseNetwork SDKs let agents discover services, invoke paid APIs, and receive auditable receipts. Start here when you want to add SynapseNetwork to an application, agent runtime, or provider API.

## Install

| Language | Install | Guide |
| --- | --- | --- |
| Python | `pip install synapse-network-ai-sdk` | [Python integration](./python_integration.md) |
| TypeScript | `npm install @synapse-network-ai/sdk` | [TypeScript integration](./typescript_integration.md) |
| Go | `go get github.com/SynapseNetworkAI/Synapse-Network-Sdk/go@latest` | [Go integration](./go_integration.md) |
| Java | `ai.synapse-network:synapse-network-sdk` | [Java integration](./java_integration.md) |
| .NET | `dotnet add package SynapseNetwork.Sdk` | [.NET integration](./dotnet_integration.md) |

## First Agent Flow

1. Create an Agent Key in the SynapseNetwork dashboard.
2. Pass it to the SDK as `SYNAPSE_AGENT_KEY` or an explicit constructor option.
3. Search for a service.
4. Invoke it with the latest discovered price.
5. Read the invocation receipt.

```python
from synapse_client import SynapseClient

client = SynapseClient()
service = client.search("invoice extraction", limit=5)[0]

result = client.invoke(
    service.service_id,
    {"invoice_url": "https://example.com/invoice.pdf"},
    cost_usdc=str(service.price_usdc),
    idempotency_key="invoice-job-001",
)

receipt = client.get_invocation(result.invocation_id)
print(receipt.status, receipt.charged_usdc)
```

## What The SDK Handles

- Service discovery across SynapseNetwork provider APIs.
- Fixed-price API invocation with price mismatch protection.
- Token-metered LLM invocation with optional spend caps.
- Receipt lookup and settlement metadata.
- Owner-authenticated provider publishing flows when you are ready to expose your own API.

## Consumer vs Provider

| Role | Start with | Why |
| --- | --- | --- |
| Agent or app calling APIs | `SynapseClient` | Search, invoke, and read receipts with an Agent Key. |
| API provider publishing services | `SynapseAuth` then `auth.provider()` | Register services, manage provider secrets, and inspect service health. |

Most integrations only need `SynapseClient` on day one. Provider publishing is a second path for teams exposing APIs to agents.

## Public References

- Product site: [www.synapse-network.ai](https://www.synapse-network.ai)
- SDK source: [github.com/SynapseNetworkAI/Synapse-Network-Sdk](https://github.com/SynapseNetworkAI/Synapse-Network-Sdk)
- Python package: [PyPI](https://pypi.org/project/synapse-network-ai-sdk/)
- TypeScript package: [npm](https://www.npmjs.com/package/@synapse-network-ai/sdk)
- Go package: [pkg.go.dev](https://pkg.go.dev/github.com/SynapseNetworkAI/Synapse-Network-Sdk/go)
- Java package: [Maven Central](https://repo1.maven.org/maven2/ai/synapse-network/synapse-network-sdk/)
- .NET package: [NuGet](https://www.nuget.org/packages/SynapseNetwork.Sdk)

## Environment

The public default is production:

```text
https://api.synapse-network.ai
```

Use an explicit gateway URL only when you are targeting a private deployment or a documented sandbox.
