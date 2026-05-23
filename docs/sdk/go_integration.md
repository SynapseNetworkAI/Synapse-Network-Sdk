# Go SDK Integration Guide

Use the Go SDK when an agent or backend service needs to discover SynapseNetwork services, invoke paid APIs, and read receipts from Go code.

## Install

```bash
go get github.com/SynapseNetworkAI/Synapse-Network-Sdk/go@latest
```

Registry: <https://pkg.go.dev/github.com/SynapseNetworkAI/Synapse-Network-Sdk/go>

## First Call

Create an Agent Key in the SynapseNetwork dashboard and expose it as `SYNAPSE_AGENT_KEY`.

```go
package main

import (
    "context"
    "fmt"
    "os"

    synapse "github.com/SynapseNetworkAI/Synapse-Network-Sdk/go/synapse"
)

func main() {
    client, err := synapse.NewClient(synapse.Options{
        Credential:  os.Getenv("SYNAPSE_AGENT_KEY"),
        Environment: "prod",
    })
    if err != nil {
        panic(err)
    }

    services, err := client.Search(context.Background(), "invoice extraction", synapse.SearchOptions{Limit: 5})
    if err != nil {
        panic(err)
    }
    service := services[0]

    result, err := client.Invoke(
        context.Background(),
        service.ServiceID,
        map[string]any{"invoice_url": "https://example.com/invoice.pdf"},
        synapse.InvokeOptions{CostUSDC: fmt.Sprint(service.Pricing["amount"])},
    )
    if err != nil {
        panic(err)
    }

    receipt, err := client.GetInvocation(context.Background(), result.InvocationID)
    if err != nil {
        panic(err)
    }
    fmt.Println(receipt.Status, receipt.ChargedUSDC)
}
```

## What You Can Build

1. Agent tools that search and invoke paid APIs.
2. Usage dashboards that reconcile receipt status and charged USDC.
3. Provider backends that publish services after the consumer flow is working.

Provider publishing is an advanced path. Start with Agent Key based consumption first, then add provider registration when you are ready to sell an API through SynapseNetwork.

## More Links

- SDK hub: <https://docs.synapse-network.ai/sdks>
- Source: <https://github.com/SynapseNetworkAI/Synapse-Network-Sdk>
