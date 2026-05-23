# SynapseNetwork TypeScript SDK

Official TypeScript SDK for agents and applications that use SynapseNetwork to discover services, invoke paid APIs, and receive auditable receipts.

## Install

```bash
npm install @synapse-network-ai/sdk
```

`ethers` is a peer dependency for owner wallet authentication:

```bash
npm install ethers
```

## Quickstart

Create an Agent Key in the SynapseNetwork dashboard, then pass it to `SynapseClient`.

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

## Token-metered LLM Calls

LLM services use token-metered pricing. Pass an optional spend cap instead of a fixed `costUsdc`:

```ts
const result = await client.invokeLlm(
  "svc_deepseek_chat",
  {
    messages: [{ role: "user", content: "Summarize this document." }],
    max_tokens: 512,
  },
  {
    maxCostUsdc: "0.010000",
    idempotencyKey: "llm-job-001",
  }
);

console.log(result.usage?.inputTokens, result.usage?.outputTokens);
console.log(result.synapse?.chargedUsdc);
```

## Provider APIs

If you operate an API that agents should call, use the provider facade from backend or operator tooling after owner authentication. Provider setup lets you register a service, publish pricing, read health, and reconcile earnings.

Provider setup is optional for consumers. Agent runtime code usually only needs `SynapseClient`.

## Links

- SDK docs: [docs.synapse-network.ai/sdks/typescript](https://docs.synapse-network.ai/sdks/typescript)
- npm: [npmjs.com/package/@synapse-network-ai/sdk](https://www.npmjs.com/package/@synapse-network-ai/sdk)
- Source: [github.com/SynapseNetworkAI/Synapse-Network-Sdk](https://github.com/SynapseNetworkAI/Synapse-Network-Sdk)

## License

MIT
