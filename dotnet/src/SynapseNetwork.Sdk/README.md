# SynapseNetwork .NET SDK

Official .NET SDK for agents and applications that use SynapseNetwork to discover services, invoke paid APIs, and receive auditable receipts.

## Install

```bash
dotnet add package SynapseNetwork.Sdk
```

## Quickstart

```csharp
using SynapseNetwork.Sdk;

var client = new SynapseClient(new SynapseClientOptions
{
    Credential = Environment.GetEnvironmentVariable("SYNAPSE_AGENT_KEY"),
    Environment = "prod",
});

var services = await client.SearchAsync("invoice extraction", new SearchOptions { Limit = 5 });
var service = services[0];

var price = service.Pricing?.TryGetProperty("amount", out var amount) == true
    ? amount.GetString() ?? "0"
    : "0";

var result = await client.InvokeAsync(
    service.ServiceId,
    new Dictionary<string, object?> { ["invoice_url"] = "https://example.com/invoice.pdf" },
    new InvokeOptions
    {
        CostUsdc = price,
        IdempotencyKey = "invoice-job-001",
    });

var receipt = await client.GetInvocationAsync(result.InvocationId);
Console.WriteLine($"{receipt.Status} {receipt.ChargedUsdc}");
```

## Links

- SDK docs: [docs.synapse-network.ai/sdks](https://docs.synapse-network.ai/sdks)
- NuGet: [nuget.org/packages/SynapseNetwork.Sdk](https://www.nuget.org/packages/SynapseNetwork.Sdk)
- Source: [github.com/SynapseNetworkAI/Synapse-Network-Sdk](https://github.com/SynapseNetworkAI/Synapse-Network-Sdk)
