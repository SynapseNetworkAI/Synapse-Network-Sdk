# .NET SDK Integration Guide

Use the .NET SDK when a `net8.0` application needs to discover SynapseNetwork services, invoke paid APIs, and read auditable receipts.

## Install

```bash
dotnet add package SynapseNetwork.Sdk --version 1.0.1
```

Registry: <https://www.nuget.org/packages/SynapseNetwork.Sdk>

## First Call

Create an Agent Key in the SynapseNetwork dashboard and expose it as `SYNAPSE_AGENT_KEY`.

```csharp
using SynapseNetwork.Sdk;

var client = new SynapseClient(new SynapseClientOptions
{
    Credential = Environment.GetEnvironmentVariable("SYNAPSE_AGENT_KEY")!,
    Environment = "prod",
});

var services = await client.SearchAsync("invoice extraction", new SearchOptions { Limit = 5 });
var service = services[0];
var price = service.Pricing?.GetProperty("amount").GetString() ?? "0";

var result = await client.InvokeAsync(
    service.ServiceId ?? service.Id!,
    new Dictionary<string, object?> { ["invoice_url"] = "https://example.com/invoice.pdf" },
    new InvokeOptions { CostUsdc = price });

var receipt = await client.GetInvocationAsync(result.InvocationId!);
Console.WriteLine($"{receipt.Status} {receipt.ChargedUsdc}");
```

## What You Can Build

1. Agent runtimes that call paid APIs with bounded spend.
2. Internal tools that reconcile receipt status and charged USDC.
3. Provider integrations that publish APIs after the consumer flow is working.

Provider publishing is an advanced path. Start with Agent Key based consumption first, then add provider registration when you are ready to sell an API through SynapseNetwork.

## More Links

- SDK hub: <https://docs.synapse-network.ai/sdks>
- Source: <https://github.com/SynapseNetworkAI/Synapse-Network-Sdk>
