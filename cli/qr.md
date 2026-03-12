---
summary: "`openclaw qr` CLI 参考（生成 iOS 配对二维码和设置码）"
read_when:
  - 希望快速将 iOS 应用与 Gateway 网关配对
  - 需要用于远程/手动共享的设置码输出
title: "qr"
---

# `openclaw qr`

根据当前 Gateway 网关配置生成 iOS 配对二维码和设置码。

## 用法

```bash
openclaw qr
openclaw qr --setup-code-only
openclaw qr --json
openclaw qr --remote
openclaw qr --url wss://gateway.example/ws --token '<token>'
```

## 选项

- `--remote`：使用配置中的 `gateway.remote.url` 加远程令牌/密码
- `--url <url>`：覆盖有效负载中使用的 Gateway 网关 URL
- `--public-url <url>`：覆盖有效负载中使用的公共 URL
- `--token <token>`：覆盖有效负载中的 Gateway 网关令牌
- `--password <password>`：覆盖有效负载中的 Gateway 网关密码
- `--setup-code-only`：仅输出设置码
- `--no-ascii`：跳过 ASCII 二维码渲染
- `--json`：输出 JSON（`setupCode`、`gatewayUrl`、`auth`、`urlSource`）

## 注意事项

- `--token` 和 `--password` 互斥。
- 使用 `--remote` 时，如果实际生效的远程凭据配置为 SecretRef 且未传入 `--token` 或 `--password`，命令会从活动的 Gateway 网关快照中解析。如果 Gateway 网关不可用，命令会快速失败。
- 不使用 `--remote` 时，当未传入 CLI 认证覆盖参数时，本地 Gateway 网关认证 SecretRef 会被解析：
  - 当令牌认证可以胜出时（显式设置 `gateway.auth.mode="token"` 或在没有密码源胜出的推断模式下），解析 `gateway.auth.token`。
  - 当密码认证可以胜出时（显式设置 `gateway.auth.mode="password"` 或在没有来自 auth/env 的胜出令牌的推断模式下），解析 `gateway.auth.password`。
- 如果同时配置了 `gateway.auth.token` 和 `gateway.auth.password`（包括 SecretRef）且 `gateway.auth.mode` 未设置，设置码解析会失败，直到显式设置 mode。
- Gateway 网关版本差异说明：此命令路径要求 Gateway 网关支持 `secrets.resolve`；较旧的 Gateway 网关会返回未知方法错误。
- 扫描后，通过以下命令批准设备配对：
  - `openclaw devices list`
  - `openclaw devices approve <requestId>`
