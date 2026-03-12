---
summary: "密钥管理：SecretRef 契约、运行时快照行为和安全的单向清除"
read_when:
  - 为提供者凭据和 `auth-profiles.json` 引用配置 SecretRef
  - 在生产环境中安全操作密钥重新加载、审计、配置和应用
  - 了解启动快速失败、非活跃表面过滤和最近已知良好行为
title: "Secrets Management"
---

# 密钥管理

OpenClaw 支持增量式 SecretRef，使得受支持的凭据无需以明文形式存储在配置中。

明文仍然有效。SecretRef 是按凭据选择性启用的。

## 目标和运行时模型

密钥被解析为内存中的运行时快照。

- 解析在激活期间是即时的，而非在请求路径上延迟执行。
- 当一个有效活跃的 SecretRef 无法解析时，启动会快速失败。
- 重新加载使用原子交换：完全成功，否则保持最近已知良好的快照。
- 运行时请求仅从活跃的内存快照中读取。
- 出站投递路径也从该活跃快照读取（例如 Discord 回复/线程投递和 Telegram 动作发送）；它们不会在每次发送时重新解析 SecretRef。

这使得密钥提供者的故障不会影响热请求路径。

## 活跃表面过滤

SecretRef 仅在有效活跃的表面上进行验证。

- 已启用的表面：未解析的引用会阻止启动/重新加载。
- 非活跃表面：未解析的引用不会阻止启动/重新加载。
- 非活跃引用会发出非致命诊断信息，代码为 `SECRETS_REF_IGNORED_INACTIVE_SURFACE`。

非活跃表面的示例：

- 已禁用的频道/账户条目。
- 没有已启用账户继承的顶级频道凭据。
- 已禁用的工具/功能表面。
- 未被 `tools.web.search.provider` 选择的 Web 搜索提供者特定密钥。
  在自动模式（未设置提供者）下，密钥按优先级顺序用于提供者自动检测，直到有一个解析成功。
  选择后，未选择的提供者密钥在被选择之前视为非活跃。
- `gateway.remote.token` / `gateway.remote.password` SecretRef 在以下任一条件为真时是活跃的：
  - `gateway.mode=remote`
  - 已配置 `gateway.remote.url`
  - `gateway.tailscale.mode` 为 `serve` 或 `funnel`
  - 在没有这些远程表面的本地模式下：
    - `gateway.remote.token` 在令牌认证可以生效且未配置 env/auth 令牌时是活跃的。
    - `gateway.remote.password` 仅在密码认证可以生效且未配置 env/auth 密码时是活跃的。
- 当设置了 `OPENCLAW_GATEWAY_TOKEN`（或 `CLAWDBOT_GATEWAY_TOKEN`）时，`gateway.auth.token` SecretRef 在启动认证解析时是非活跃的，因为环境变量令牌输入在该运行时中优先。

## Gateway 认证表面诊断

当在 `gateway.auth.token`、`gateway.auth.password`、`gateway.remote.token` 或 `gateway.remote.password` 上配置了 SecretRef 时，Gateway 启动/重新加载会显式记录表面状态：

- `active`：SecretRef 是有效认证表面的一部分，必须解析。
- `inactive`：该 SecretRef 在此运行时中被忽略，因为另一个认证表面优先，或因为远程认证已禁用/未激活。

这些条目以 `SECRETS_GATEWAY_AUTH_SURFACE` 记录，并包含活跃表面策略使用的原因，以便你可以了解凭据被视为活跃或非活跃的原因。

## 引导参考预检

当引导在交互模式下运行并且你选择 SecretRef 存储时，OpenClaw 在保存前运行预检验证：

- 环境变量引用：验证环境变量名称并确认在引导过程中可见非空值。
- 提供者引用（`file` 或 `exec`）：验证提供者选择，解析 `id`，并检查解析值类型。
- 快速入门复用路径：当 `gateway.auth.token` 已经是 SecretRef 时，引导在探测/仪表板引导之前解析它（对于 `env`、`file` 和 `exec` 引用），使用相同的快速失败门控。

如果验证失败，引导会显示错误并让你重试。

## SecretRef 契约

在所有地方使用一个对象结构：

```json5
{ source: "env" | "file" | "exec", provider: "default", id: "..." }
```

### `source: "env"`

```json5
{ source: "env", provider: "default", id: "OPENAI_API_KEY" }
```

验证：

- `provider` 必须匹配 `^[a-z][a-z0-9_-]{0,63}$`
- `id` 必须匹配 `^[A-Z][A-Z0-9_]{0,127}$`

### `source: "file"`

```json5
{ source: "file", provider: "filemain", id: "/providers/openai/apiKey" }
```

验证：

- `provider` 必须匹配 `^[a-z][a-z0-9_-]{0,63}$`
- `id` 必须是绝对 JSON 指针（`/...`）
- RFC6901 段中转义：`~` => `~0`，`/` => `~1`

### `source: "exec"`

```json5
{ source: "exec", provider: "vault", id: "providers/openai/apiKey" }
```

验证：

- `provider` 必须匹配 `^[a-z][a-z0-9_-]{0,63}$`
- `id` 必须匹配 `^[A-Za-z0-9][A-Za-z0-9._:/-]{0,255}$`
- `id` 不能包含 `.` 或 `..` 作为斜杠分隔的路径段（例如 `a/../b` 会被拒绝）

## 提供者配置

在 `secrets.providers` 下定义提供者：

```json5
{
  secrets: {
    providers: {
      default: { source: "env" },
      filemain: {
        source: "file",
        path: "~/.openclaw/secrets.json",
        mode: "json", // or "singleValue"
      },
      vault: {
        source: "exec",
        command: "/usr/local/bin/openclaw-vault-resolver",
        args: ["--profile", "prod"],
        passEnv: ["PATH", "VAULT_ADDR"],
        jsonOnly: true,
      },
    },
    defaults: {
      env: "default",
      file: "filemain",
      exec: "vault",
    },
    resolution: {
      maxProviderConcurrency: 4,
      maxRefsPerProvider: 512,
      maxBatchBytes: 262144,
    },
  },
}
```

### Env 提供者

- 可选的允许列表通过 `allowlist` 配置。
- 缺失/空的环境变量值会导致解析失败。

### File 提供者

- 从 `path` 读取本地文件。
- `mode: "json"` 期望 JSON 对象载荷，并将 `id` 作为指针解析。
- `mode: "singleValue"` 期望引用 id 为 `"value"` 并返回文件内容。
- 路径必须通过所有权/权限检查。
- Windows 安全关闭说明：如果某路径的 ACL 验证不可用，解析会失败。仅对受信任路径，在该提供者上设置 `allowInsecurePath: true` 以绕过路径安全检查。

### Exec 提供者

- 运行配置的绝对二进制路径，不使用 shell。
- 默认情况下，`command` 必须指向普通文件（非符号链接）。
- 设置 `allowSymlinkCommand: true` 以允许符号链接命令路径（例如 Homebrew shims）。OpenClaw 会验证解析后的目标路径。
- 将 `allowSymlinkCommand` 与 `trustedDirs` 配合使用，用于包管理器路径（例如 `["/opt/homebrew"]`）。
- 支持超时、无输出超时、输出字节限制、环境变量允许列表和受信任目录。
- Windows 安全关闭说明：如果命令路径的 ACL 验证不可用，解析会失败。仅对受信任路径，在该提供者上设置 `allowInsecurePath: true` 以绕过路径安全检查。

请求载荷（stdin）：

```json
{ "protocolVersion": 1, "provider": "vault", "ids": ["providers/openai/apiKey"] }
```

响应载荷（stdout）：

```jsonc
{ "protocolVersion": 1, "values": { "providers/openai/apiKey": "<openai-api-key>" } } // pragma: allowlist secret
```

可选的逐 id 错误：

```json
{
  "protocolVersion": 1,
  "values": {},
  "errors": { "providers/openai/apiKey": { "message": "not found" } }
}
```

## Exec 集成示例

### 1Password CLI

```json5
{
  secrets: {
    providers: {
      onepassword_openai: {
        source: "exec",
        command: "/opt/homebrew/bin/op",
        allowSymlinkCommand: true, // required for Homebrew symlinked binaries
        trustedDirs: ["/opt/homebrew"],
        args: ["read", "op://Personal/OpenClaw QA API Key/password"],
        passEnv: ["HOME"],
        jsonOnly: false,
      },
    },
  },
  models: {
    providers: {
      openai: {
        baseUrl: "https://api.openai.com/v1",
        models: [{ id: "gpt-5", name: "gpt-5" }],
        apiKey: { source: "exec", provider: "onepassword_openai", id: "value" },
      },
    },
  },
}
```

### HashiCorp Vault CLI

```json5
{
  secrets: {
    providers: {
      vault_openai: {
        source: "exec",
        command: "/opt/homebrew/bin/vault",
        allowSymlinkCommand: true, // required for Homebrew symlinked binaries
        trustedDirs: ["/opt/homebrew"],
        args: ["kv", "get", "-field=OPENAI_API_KEY", "secret/openclaw"],
        passEnv: ["VAULT_ADDR", "VAULT_TOKEN"],
        jsonOnly: false,
      },
    },
  },
  models: {
    providers: {
      openai: {
        baseUrl: "https://api.openai.com/v1",
        models: [{ id: "gpt-5", name: "gpt-5" }],
        apiKey: { source: "exec", provider: "vault_openai", id: "value" },
      },
    },
  },
}
```

### `sops`

```json5
{
  secrets: {
    providers: {
      sops_openai: {
        source: "exec",
        command: "/opt/homebrew/bin/sops",
        allowSymlinkCommand: true, // required for Homebrew symlinked binaries
        trustedDirs: ["/opt/homebrew"],
        args: ["-d", "--extract", '["providers"]["openai"]["apiKey"]', "/path/to/secrets.enc.json"],
        passEnv: ["SOPS_AGE_KEY_FILE"],
        jsonOnly: false,
      },
    },
  },
  models: {
    providers: {
      openai: {
        baseUrl: "https://api.openai.com/v1",
        models: [{ id: "gpt-5", name: "gpt-5" }],
        apiKey: { source: "exec", provider: "sops_openai", id: "value" },
      },
    },
  },
}
```

## 支持的凭据表面

规范的受支持和不受支持凭据列在：

- [SecretRef 凭据表面](/reference/secretref-credential-surface)

运行时生成的或轮换的凭据以及 OAuth 刷新材料被有意排除在只读 SecretRef 解析之外。

## 必需行为和优先级

- 没有引用的字段：保持不变。
- 有引用的字段：在激活期间在活跃表面上是必需的。
- 如果同时存在明文和引用，在支持的优先级路径上引用优先。

警告和审计信号：

- `SECRETS_REF_OVERRIDES_PLAINTEXT`（运行时警告）
- `REF_SHADOWED`（当 `auth-profiles.json` 凭据优先于 `openclaw.json` 引用时的审计发现）

Google Chat 兼容性行为：

- `serviceAccountRef` 优先于明文 `serviceAccount`。
- 当设置了同级引用时，明文值被忽略。

## 激活触发器

密钥激活在以下时机运行：

- 启动（预检加最终激活）
- 配置重新加载热应用路径
- 配置重新加载重启检查路径
- 通过 `secrets.reload` 手动重新加载

激活契约：

- 成功时原子交换快照。
- 启动失败会中止 Gateway 启动。
- 运行时重新加载失败会保持最近已知良好的快照。
- 向出站辅助/工具调用提供显式的逐调用频道令牌不会触发 SecretRef 激活；激活点仍然是启动、重新加载和显式的 `secrets.reload`。

## 降级和恢复信号

当重新加载时激活在健康状态后失败，OpenClaw 进入降级密钥状态。

一次性系统事件和日志代码：

- `SECRETS_RELOADER_DEGRADED`
- `SECRETS_RELOADER_RECOVERED`

行为：

- 降级：运行时保持最近已知良好的快照。
- 恢复：在下一次成功激活后发出一次。
- 已处于降级状态时的重复失败记录警告但不会频繁发出事件。
- 启动快速失败不会发出降级事件，因为运行时从未变为活跃。

## 命令路径解析

命令路径可以通过 Gateway 快照 RPC 选择性加入受支持的 SecretRef 解析。

有两种广泛的行为：

- 严格命令路径（例如 `openclaw memory` 远程内存路径和 `openclaw qr --remote`）从活跃快照读取，当所需的 SecretRef 不可用时快速失败。
- 只读命令路径（例如 `openclaw status`、`openclaw status --all`、`openclaw channels status`、`openclaw channels resolve` 和只读 doctor/配置修复流程）也优先使用活跃快照，但在该命令路径中目标 SecretRef 不可用时降级而非中止。

只读行为：

- 当 Gateway 正在运行时，这些命令首先从活跃快照读取。
- 如果 Gateway 解析不完整或 Gateway 不可用，它们会尝试针对特定命令表面进行本地回退。
- 如果目标 SecretRef 仍然不可用，命令继续以降级只读输出和显式诊断（如 "configured but unavailable in this command path"）运行。
- 此降级行为仅限于命令本地。它不会削弱运行时启动、重新加载或发送/认证路径。

其他说明：

- 后端密钥轮换后的快照刷新由 `openclaw secrets reload` 处理。
- 这些命令路径使用的 Gateway RPC 方法：`secrets.resolve`。

## 审计和配置工作流

默认操作者流程：

```bash
openclaw secrets audit --check
openclaw secrets configure
openclaw secrets audit --check
```

### `secrets audit`

发现包括：

- 静态明文值（`openclaw.json`、`auth-profiles.json`、`.env` 和生成的 `agents/*/agent/models.json`）
- 生成的 `models.json` 条目中的明文敏感提供者头残留
- 未解析的引用
- 优先级覆盖（`auth-profiles.json` 优先于 `openclaw.json` 引用）
- 遗留残留（`auth.json`、OAuth 提醒）

头残留说明：

- 敏感提供者头检测基于名称启发式（常见的认证/凭据头名称和片段，如 `authorization`、`x-api-key`、`token`、`secret`、`password` 和 `credential`）。

### `secrets configure`

交互式助手，可以：

- 首先配置 `secrets.providers`（`env`/`file`/`exec`，添加/编辑/删除）
- 让你选择 `openclaw.json` 中支持的密钥承载字段以及一个代理范围的 `auth-profiles.json`
- 可以直接在目标选择器中创建新的 `auth-profiles.json` 映射
- 捕获 SecretRef 详情（`source`、`provider`、`id`）
- 运行预检解析
- 可以立即应用

有用的模式：

- `openclaw secrets configure --providers-only`
- `openclaw secrets configure --skip-provider-setup`
- `openclaw secrets configure --agent <id>`

`configure` 应用默认值：

- 清除目标提供者的 `auth-profiles.json` 中匹配的静态凭据
- 清除 `auth.json` 中遗留的静态 `api_key` 条目
- 清除 `<config-dir>/.env` 中匹配的已知密钥行

### `secrets apply`

应用已保存的计划：

```bash
openclaw secrets apply --from /tmp/openclaw-secrets-plan.json
openclaw secrets apply --from /tmp/openclaw-secrets-plan.json --dry-run
```

严格的目标/路径契约详情和确切的拒绝规则，请参见：

- [Secrets Apply 计划契约](/gateway/secrets-plan-contract)

## 单向安全策略

OpenClaw 有意不写入包含历史明文密钥值的回滚备份。

安全模型：

- 预检必须在写入模式之前成功
- 运行时激活在提交之前进行验证
- apply 使用原子文件替换更新文件，失败时尽力恢复

## 遗留认证兼容性说明

对于静态凭据，运行时不再依赖明文遗留认证存储。

- 运行时凭据来源是已解析的内存快照。
- 遗留静态 `api_key` 条目在被发现时会被清除。
- OAuth 相关的兼容性行为保持独立。

## Web UI 说明

某些 SecretInput 联合类型在原始编辑器模式下比表单模式更容易配置。

## 相关文档

- CLI 命令：[secrets](/cli/secrets)
- 计划契约详情：[Secrets Apply 计划契约](/gateway/secrets-plan-contract)
- 凭据表面：[SecretRef 凭据表面](/reference/secretref-credential-surface)
- 认证设置：[认证](/gateway/authentication)
- 安全态势：[安全](/gateway/security)
- 环境变量优先级：[环境变量](/help/environment)
