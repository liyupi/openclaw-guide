---
title: Vercel AI Gateway
---
[Vercel AI Gateway](https://vercel.com/ai-gateway) 提供了一个统一的 API，通过单一端点访问数百个模型。

- 提供商：`vercel-ai-gateway`
- 认证：`AI_GATEWAY_API_KEY`
- API：兼容 Anthropic Messages

## 快速开始

1. 设置 API 密钥（推荐：为 Gateway 网关存储它）：

```bash
openclaw onboard --auth-choice ai-gateway-api-key
```

2. 设置默认模型：

```json5
{
  agents: {
    defaults: {
      model: { primary: "vercel-ai-gateway/anthropic/claude-opus-4.5" },
    },
  },
}
```

## 非交互式示例

```bash
openclaw onboard --non-interactive \
  --mode local \
  --auth-choice ai-gateway-api-key \
  --ai-gateway-api-key "$AI_GATEWAY_API_KEY"
```

## 环境变量说明

如果 Gateway 网关作为守护进程运行（launchd/systemd），请确保 `AI_GATEWAY_API_KEY`
对该进程可用（例如，在 `~/.openclaw/.env` 中或通过
`env.shellEnv`）。
