---
summary: "使用 OpenCode Go 目录及共享 OpenCode 设置"
read_when:
  - 你想使用 OpenCode Go 目录
  - 你需要 Go 托管模型的运行时模型引用
title: "OpenCode Go"
---

# OpenCode Go

OpenCode Go 是 [OpenCode](/providers/opencode) 中的 Go 目录。它使用与 Zen 目录相同的 `OPENCODE_API_KEY`，但保留运行时提供商 ID `opencode-go`，以确保上游按模型路由保持正确。

## 支持的模型

- `opencode-go/kimi-k2.5`
- `opencode-go/glm-5`
- `opencode-go/minimax-m2.5`

## CLI 设置

```bash
openclaw onboard --auth-choice opencode-go
# or non-interactive
openclaw onboard --opencode-go-api-key "$OPENCODE_API_KEY"
```

## 配置片段

```json5
{
  env: { OPENCODE_API_KEY: "YOUR_API_KEY_HERE" }, // pragma: allowlist secret
  agents: { defaults: { model: { primary: "opencode-go/kimi-k2.5" } } },
}
```

## 路由行为

当模型引用使用 `opencode-go/...` 时，OpenClaw 会自动处理按模型路由。

## 注意事项

- 共享引导和目录概览请参阅 [OpenCode](/providers/opencode)。
- 运行时引用保持显式：`opencode/...` 对应 Zen，`opencode-go/...` 对应 Go。
