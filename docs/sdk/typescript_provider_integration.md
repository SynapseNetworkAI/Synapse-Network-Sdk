# TypeScript Provider Integration Guide

Use the TypeScript provider APIs when you want to publish a service that agents can discover and invoke through SynapseNetwork. Provider publishing is the second path; if you only want to call services, start with `SynapseClient` in the TypeScript integration guide.

## Install

```bash
npm install @synapse-network-ai/sdk
```

## Minimal Provider Flow

```ts
import { SynapseAuth } from "@synapse-network-ai/sdk";

const wallet = loadServerSideSigner();
const auth = SynapseAuth.fromWallet(wallet, { environment: "prod" });
const provider = auth.provider();

const secret = await provider.issueSecret({
  name: "invoice-ocr-production",
  rpm: 180,
  creditLimit: 25,
  resetInterval: "monthly",
});

const registered = await provider.registerService({
  serviceName: "Invoice OCR",
  endpointUrl: "https://provider.example.com/invoke",
  basePriceUsdc: "0.008",
  descriptionForModel: "Extract structured invoice fields from invoice images.",
});

console.log(secret.secret.maskedKey, registered.serviceId);
```

`loadServerSideSigner()` represents your own secure wallet signer. Keep provider setup in backend or operator tooling; do not ship owner signing material to browser or agent runtime code.

## What Provider APIs Do

1. Issue scoped provider secrets.
2. Register fixed-price or token-metered services.
3. Read service status, health, earnings, and withdrawal capability.

Keep provider setup in backend or operator tooling. Agent runtime code should keep using `SynapseClient` with an Agent Key.

## More Links

- SDK hub: <https://docs.synapse-network.ai/sdks>
- Source: <https://github.com/SynapseNetworkAI/Synapse-Network-Sdk>
