# Java/JVM SDK Integration Guide

Use the Java SDK when a JVM application needs to discover SynapseNetwork services, invoke paid APIs, and read auditable receipts. Kotlin and other JVM languages can call the Java SDK directly.

## Install

```xml
<dependency>
  <groupId>ai.synapse-network</groupId>
  <artifactId>synapse-network-sdk</artifactId>
  <version>1.0.1</version>
</dependency>
```

Registry: <https://repo1.maven.org/maven2/ai/synapse-network/synapse-network-sdk/>

## First Call

Create an Agent Key in the SynapseNetwork dashboard and expose it as `SYNAPSE_AGENT_KEY`.

```java
import ai.synapsenetwork.sdk.SynapseClient;
import java.util.Map;

SynapseClient client = new SynapseClient(
    SynapseClient.options(System.getenv("SYNAPSE_AGENT_KEY")).environment("prod"));

var services = client.search("invoice extraction", new SynapseClient.SearchOptions());
var service = services.get(0);

SynapseClient.InvokeOptions options = new SynapseClient.InvokeOptions();
options.costUsdc = service.pricing().path("amount").asText("0");

var result = client.invoke(
    service.serviceId(),
    Map.of("invoice_url", "https://example.com/invoice.pdf"),
    options);

var receipt = client.getInvocation(result.invocationId());
System.out.println(receipt.status() + " " + receipt.chargedUsdc());
```

## What You Can Build

1. Agent runtimes that call paid APIs with bounded spend.
2. Back-office services that store invocation receipts.
3. Provider integrations that publish APIs after the consumer flow is working.

Provider publishing is an advanced path. Start with Agent Key based consumption first, then add provider registration when you are ready to sell an API through SynapseNetwork.

## More Links

- SDK hub: <https://docs.synapse-network.ai/sdks>
- Source: <https://github.com/SynapseNetworkAI/Synapse-Network-Sdk>
