---
title: Firecrawl
---
OpenClaw 可以使用 **Firecrawl** 作为 `web_fetch` 的回退提取器。它是一个托管的
内容提取服务，支持机器人规避和缓存，有助于处理
JS 密集型网站或阻止普通 HTTP 请求的页面。

## 获取 API 密钥

1. 创建 Firecrawl 账户并生成 API 密钥。
2. 将其存储在配置中或在 Gateway 网关环境中设置 `FIRECRAWL_API_KEY`。

## 配置 Firecrawl

```json5
{
  tools: {
    web: {
      fetch: {
        firecrawl: {
          apiKey: "FIRECRAWL_API_KEY_HERE",
          baseUrl: "https://api.firecrawl.dev",
          onlyMainContent: true,
          maxAgeMs: 172800000,
          timeoutSeconds: 60,
        },
      },
    },
  },
}
```

注意事项：

- 当存在 API 密钥时，`firecrawl.enabled` 默认为 true。
- `maxAgeMs` 控制缓存结果可以保留多久（毫秒）。默认为 2 天。

## 隐身 / 机器人规避

Firecrawl 提供了一个用于机器人规避的**代理模式**参数（`basic`、`stealth` 或 `auto`）。
OpenClaw 对 Firecrawl 请求始终使用 `proxy: "auto"` 加 `storeInCache: true`。
如果省略 proxy，Firecrawl 默认使用 `auto`。`auto` 在基本尝试失败时会使用隐身代理重试，这可能比
仅使用基本抓取消耗更多积分。

## `web_fetch` 如何使用 Firecrawl

`web_fetch` 提取顺序：

1. Readability（本地）
2. Firecrawl（如果已配置）
3. 基本 HTML 清理（最后回退）

参见 [Web 工具](/tools/web) 了解完整的 Web 工具设置。
