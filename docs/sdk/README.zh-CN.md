<p align="center">
  <a href="./README.md">English</a> · <strong>简体中文</strong>
</p>

# SynapseNetwork SDK 中心

SynapseNetwork SDK 帮助 Agent 发现服务、调用付费 API，并读取可审计的调用回执。

## 安装

| 语言 | 安装 | 文档 |
| --- | --- | --- |
| Python | `pip install synapse-network-ai-sdk` | [Python 接入](./python_integration.md) |
| TypeScript | `npm install @synapse-network-ai/sdk` | [TypeScript 接入](./typescript_integration.md) |
| Go | `go get github.com/SynapseNetworkAI/Synapse-Network-Sdk/go@latest` | [Go 接入](./go_integration.md) |
| Java | `ai.synapse-network:synapse-network-sdk` | [Java 接入](./java_integration.md) |
| .NET | `dotnet add package SynapseNetwork.Sdk` | [.NET 接入](./dotnet_integration.md) |

## 第一次调用

1. 在 SynapseNetwork 控制台创建 Agent Key。
2. 将 Agent Key 传给 SDK。
3. 搜索一个服务。
4. 使用发现结果里的最新价格调用服务。
5. 读取调用回执和扣费信息。

```python
from synapse_client import SynapseClient

client = SynapseClient(api_key="agt_xxx")
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

## SDK 能做什么

- 搜索 SynapseNetwork 上的可调用服务。
- 使用价格断言调用 fixed-price API。
- 调用按 token 计费的 LLM 服务。
- 读取调用回执、扣费金额和结算状态。
- 在需要发布 API 时，通过 provider facade 注册服务。

## Consumer 与 Provider

| 角色 | 入口 | 用途 |
| --- | --- | --- |
| 调用 API 的 Agent 或应用 | `SynapseClient` | 搜索、调用、读取回执。 |
| 发布 API 的 Provider | `SynapseAuth` + `auth.provider()` | 注册服务、管理 provider secret、查看健康状态。 |

绝大多数接入第一天只需要 `SynapseClient`。Provider 发布是第二入口。

## 公共链接

- 官网: [www.synapse-network.ai](https://www.synapse-network.ai)
- SDK 源码: [github.com/SynapseNetworkAI/Synapse-Network-Sdk](https://github.com/SynapseNetworkAI/Synapse-Network-Sdk)
- Python: [PyPI](https://pypi.org/project/synapse-network-ai-sdk/)
- TypeScript: [npm](https://www.npmjs.com/package/@synapse-network-ai/sdk)
- Go: [pkg.go.dev](https://pkg.go.dev/github.com/SynapseNetworkAI/Synapse-Network-Sdk/go)
- Java: [Maven Central](https://repo1.maven.org/maven2/ai/synapse-network/synapse-network-sdk/)
- .NET: [NuGet](https://www.nuget.org/packages/SynapseNetwork.Sdk)

## 环境

公开 SDK 默认使用生产 API：

```text
https://api.synapse-network.ai
```

只有在接入私有部署或明确的测试沙箱时，才需要显式覆盖 gateway URL。
