---
title: Brave Search
---
OpenClaw 使用 Brave Search 作为 `web_search` 的默认提供商。

## 获取 API 密钥

1. 在 https://brave.com/search/api/ 创建 Brave Search API 账户
2. 在控制面板中，选择 **Data for Search** 套餐并生成 API 密钥。
3. 将密钥存储在配置中（推荐），或在 Gateway 网关环境中设置 `BRAVE_API_KEY`。

## 配置示例

```json5
{
  tools: {
    web: {
      search: {
        provider: "brave",
        apiKey: "BRAVE_API_KEY_HERE",
        maxResults: 5,
        timeoutSeconds: 30,
      },
    },
  },
}
```

## 注意事项

- Data for AI 套餐与 `web_search` **不**兼容。
- Brave 提供免费层级和付费套餐；请查看 Brave API 门户了解当前限制。

请参阅 [Web 工具](/tools/web) 了解完整的 web_search 配置。
