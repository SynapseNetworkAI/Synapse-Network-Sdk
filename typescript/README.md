# SynapseNetwork TypeScript SDK

Official TypeScript SDK for agents and applications that use SynapseNetwork to discover services, invoke APIs, and receive auditable USDC settlement receipts.

SynapseNetwork gives agents a scoped Agent Key instead of an unlimited API key or credit card. Your code can search for a service, invoke it with an explicit price or spend cap, then verify the receipt that records what happened.

## Install

```bash
npm install @synapse-network-ai/sdk
```

`ethers` is a peer dependency only for owner wallet authentication and provider publishing flows:

```bash
npm install ethers
```

## Five-minute quickstart

Create an Agent Key in the SynapseNetwork dashboard, then pass it to `SynapseClient`.

Production is the default SDK environment and uses:

```text
https://api.synapse-network.ai
```

Search for a service, invoke it with the discovered fixed price, then read the receipt:

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

## Try the free echo service

For a production connectivity smoke test, call the first-party echo service. It is intended for SDK checks and should charge `0` USDC.

```bash
export SYNAPSE_AGENT_KEY=agt_xxx
```

```ts
import { SynapseClient } from "@synapse-network-ai/sdk";

const client = new SynapseClient({
  credential: process.env.SYNAPSE_AGENT_KEY!,
  environment: "prod",
});

const result = await client.invoke(
  "svc_synapse_echo",
  { message: "hello from the TypeScript SDK" },
  {
    costUsdc: "0",
    idempotencyKey: "typescript-echo-001",
  }
);

const receipt = await client.getInvocation(result.invocationId);
console.log(receipt.status, receipt.chargedUsdc);
```

## Invocation modes

| Mode | Use for | SDK method | Billing input |
| --- | --- | --- | --- |
| Fixed-price API | Normal provider APIs with a known price | `invoke()` | Pass the latest discovered price as `costUsdc` |
| Token-metered LLM | LLM services priced by input and output tokens | `invokeLlm()` | Pass an optional spend cap such as `maxCostUsdc` |

LLM example:

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

Most users start as consumers with `SynapseClient`. If you operate an API that agents should call, use `SynapseAuth` and the provider facade from backend or operator tooling after owner authentication.

Provider setup lets you register services, publish pricing, inspect health, and reconcile earnings. Keep normal agent runtime code on `SynapseClient` with an existing Agent Key.

## Safety rules

- Do not commit Agent Keys, owner private keys, provider secrets, wallet seed phrases, or production tokens.
- Pass money values as strings such as `"0"` or `"0.05"`; do not recompute settlement amounts with floating-point math.
- Use the discovered fixed price for `invoke()` and a spend cap for `invokeLlm()`.
- Use `gatewayUrl` only for private deployments or documented sandboxes. Public examples should target production.

## Links

- SDK docs: [docs.synapse-network.ai/sdks/typescript](https://docs.synapse-network.ai/sdks/typescript)
- npm: [npmjs.com/package/@synapse-network-ai/sdk](https://www.npmjs.com/package/@synapse-network-ai/sdk)
- Source: [github.com/SynapseNetworkAI/Synapse-Network-Sdk](https://github.com/SynapseNetworkAI/Synapse-Network-Sdk)
- Issues: [github.com/SynapseNetworkAI/Synapse-Network-Sdk/issues](https://github.com/SynapseNetworkAI/Synapse-Network-Sdk/issues)

## License

MIT
