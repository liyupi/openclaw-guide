---
summary: "使用 ACP 运行时会话运行 Pi、Claude Code、Codex、OpenCode、Gemini CLI 及其他工具代理"
read_when:
  - 通过 ACP 运行编码工具
  - 在支持线程的频道上设置线程绑定的 ACP 会话
  - 将 Discord 频道或 Telegram 论坛主题绑定到持久 ACP 会话
  - 排查 ACP 后端和插件连接问题
  - 从聊天中操作 /acp 命令
title: "ACP Agents"
---

# ACP 代理

[Agent Client Protocol (ACP)](https://agentclientprotocol.com/) 会话允许 OpenClaw 通过 ACP 后端插件运行外部编码工具（例如 Pi、Claude Code、Codex、OpenCode 和 Gemini CLI）。

如果你用自然语言要求 OpenClaw "在 Codex 中运行这个" 或 "在线程中启动 Claude Code"，OpenClaw 应将该请求路由到 ACP 运行时（而非原生子代理运行时）。

## 快速操作流程

当你需要实用的 `/acp` 操作手册时使用：

1. 创建一个会话：
   - `/acp spawn codex --mode persistent --thread auto`
2. 在绑定的线程中工作（或显式指定该会话密钥）。
3. 检查运行时状态：
   - `/acp status`
4. 按需调整运行时选项：
   - `/acp model <provider/model>`
   - `/acp permissions <profile>`
   - `/acp timeout <seconds>`
5. 在不替换上下文的情况下引导活跃会话：
   - `/acp steer tighten logging and continue`
6. 停止工作：
   - `/acp cancel`（停止当前轮次），或
   - `/acp close`（关闭会话 + 移除绑定）

## 人类用户快速入门

自然语言请求示例：

- "在这里的线程中启动一个持久 Codex 会话并保持专注。"
- "将此作为一次性 Claude Code ACP 会话运行并总结结果。"
- "在线程中使用 Gemini CLI 完成此任务，然后在同一线程中继续后续操作。"

OpenClaw 应执行的操作：

1. 选择 `runtime: "acp"`。
2. 解析请求的工具目标（`agentId`，例如 `codex`）。
3. 如果请求线程绑定且当前频道支持，将 ACP 会话绑定到线程。
4. 将后续线程消息路由到同一 ACP 会话，直到取消关注/关闭/过期。

## ACP 与子代理对比

当你需要外部工具运行时使用 ACP。当你需要 OpenClaw 原生委托运行时使用子代理。

| 方面          | ACP 会话                              | 子代理运行                             |
| ------------- | ------------------------------------- | ---------------------------------- |
| 运行时        | ACP 后端插件（例如 acpx）             | OpenClaw 原生子代理运行时          |
| 会话密钥      | `agent:<agentId>:acp:<uuid>`          | `agent:<agentId>:subagent:<uuid>`  |
| 主要命令      | `/acp ...`                            | `/subagents ...`                   |
| 创建工具      | `sessions_spawn` 附带 `runtime:"acp"` | `sessions_spawn`（默认运行时）     |

另请参阅[子代理](/tools/subagents)。

## 线程绑定会话（频道无关）

当为频道适配器启用线程绑定时，ACP 会话可以绑定到线程：

- OpenClaw 将线程绑定到目标 ACP 会话。
- 该线程中的后续消息路由到绑定的 ACP 会话。
- ACP 输出发送回同一线程。
- 取消关注/关闭/归档/空闲超时或最大期限到期时移除绑定。

线程绑定支持因适配器而异。如果当前频道适配器不支持线程绑定，OpenClaw 返回明确的不支持/不可用消息。

线程绑定 ACP 所需的功能标志：

- `acp.enabled=true`
- `acp.dispatch.enabled` 默认开启（设为 `false` 可暂停 ACP 分发）
- 频道适配器 ACP 线程创建标志已启用（因适配器而异）
  - Discord：`channels.discord.threadBindings.spawnAcpSessions=true`
  - Telegram：`channels.telegram.threadBindings.spawnAcpSessions=true`

### 支持线程的频道

- 任何暴露会话/线程绑定能力的频道适配器。
- 当前内置支持：
  - Discord 线程/频道
  - Telegram 主题（群组/超级群组中的论坛主题和私聊主题）
- 插件频道可以通过相同的绑定接口添加支持。

## 频道特定设置

对于非临时工作流，在顶层 `bindings[]` 条目中配置持久 ACP 绑定。

### 绑定模型

- `bindings[].type="acp"` 标记持久 ACP 对话绑定。
- `bindings[].match` 标识目标对话：
  - Discord 频道或线程：`match.channel="discord"` + `match.peer.id="<channelOrThreadId>"`
  - Telegram 论坛主题：`match.channel="telegram"` + `match.peer.id="<chatId>:topic:<topicId>"`
- `bindings[].agentId` 是所属 OpenClaw 代理 ID。
- 可选的 ACP 覆盖项位于 `bindings[].acp` 下：
  - `mode`（`persistent` 或 `oneshot`）
  - `label`
  - `cwd`
  - `backend`

### 每个代理的运行时默认值

使用 `agents.list[].runtime` 为每个代理定义一次 ACP 默认值：

- `agents.list[].runtime.type="acp"`
- `agents.list[].runtime.acp.agent`（工具 ID，例如 `codex` 或 `claude`）
- `agents.list[].runtime.acp.backend`
- `agents.list[].runtime.acp.mode`
- `agents.list[].runtime.acp.cwd`

ACP 绑定会话的覆盖优先级：

1. `bindings[].acp.*`
2. `agents.list[].runtime.acp.*`
3. 全局 ACP 默认值（例如 `acp.backend`）

示例：

```json5
{
  agents: {
    list: [
      {
        id: "codex",
        runtime: {
          type: "acp",
          acp: {
            agent: "codex",
            backend: "acpx",
            mode: "persistent",
            cwd: "/workspace/openclaw",
          },
        },
      },
      {
        id: "claude",
        runtime: {
          type: "acp",
          acp: { agent: "claude", backend: "acpx", mode: "persistent" },
        },
      },
    ],
  },
  bindings: [
    {
      type: "acp",
      agentId: "codex",
      match: {
        channel: "discord",
        accountId: "default",
        peer: { kind: "channel", id: "222222222222222222" },
      },
      acp: { label: "codex-main" },
    },
    {
      type: "acp",
      agentId: "claude",
      match: {
        channel: "telegram",
        accountId: "default",
        peer: { kind: "group", id: "-1001234567890:topic:42" },
      },
      acp: { cwd: "/workspace/repo-b" },
    },
    {
      type: "route",
      agentId: "main",
      match: { channel: "discord", accountId: "default" },
    },
    {
      type: "route",
      agentId: "main",
      match: { channel: "telegram", accountId: "default" },
    },
  ],
  channels: {
    discord: {
      guilds: {
        "111111111111111111": {
          channels: {
            "222222222222222222": { requireMention: false },
          },
        },
      },
    },
    telegram: {
      groups: {
        "-1001234567890": {
          topics: { "42": { requireMention: false } },
        },
      },
    },
  },
}
```

行为：

- OpenClaw 在使用前确保已配置的 ACP 会话存在。
- 该频道或主题中的消息路由到已配置的 ACP 会话。
- 在绑定的对话中，`/new` 和 `/reset` 就地重置同一 ACP 会话密钥。
- 临时运行时绑定（例如由线程聚焦流程创建的）在存在时仍然适用。

## 启动 ACP 会话（接口）

### 通过 `sessions_spawn`

使用 `runtime: "acp"` 从代理轮次或工具调用启动 ACP 会话。

```json
{
  "task": "Open the repo and summarize failing tests",
  "runtime": "acp",
  "agentId": "codex",
  "thread": true,
  "mode": "session"
}
```

注意事项：

- `runtime` 默认为 `subagent`，因此需要显式设置 `runtime: "acp"` 以启动 ACP 会话。
- 如果省略 `agentId`，当配置了 `acp.defaultAgent` 时 OpenClaw 会使用该值。
- `mode: "session"` 需要 `thread: true` 以保持持久绑定对话。

接口详情：

- `task`（必填）：发送到 ACP 会话的初始提示词。
- `runtime`（ACP 必填）：必须为 `"acp"`。
- `agentId`（可选）：ACP 目标工具 ID。如果设置了 `acp.defaultAgent` 则回退到该值。
- `thread`（可选，默认 `false`）：在支持的场景中请求线程绑定流程。
- `mode`（可选）：`run`（一次性）或 `session`（持久）。
  - 默认为 `run`
  - 如果 `thread: true` 且未指定 mode，OpenClaw 可能会根据运行时路径默认为持久行为
  - `mode: "session"` 需要 `thread: true`
- `cwd`（可选）：请求的运行时工作目录（由后端/运行时策略验证）。
- `label`（可选）：在会话/横幅文本中使用的面向操作者的标签。
- `resumeSessionId`（可选）：恢复现有 ACP 会话而非创建新会话。代理通过 `session/load` 重放其对话历史。需要 `runtime: "acp"`。
- `streamTo`（可选）：`"parent"` 将初始 ACP 运行进度摘要作为系统事件流式传回请求方会话。
  - 可用时，接受的响应包含 `streamLogPath`，指向一个会话范围的 JSONL 日志（`<sessionId>.acp-stream.jsonl`），你可以 tail 查看完整的中继历史。

### 恢复现有会话

使用 `resumeSessionId` 继续之前的 ACP 会话而非重新开始。代理通过 `session/load` 重放其对话历史，因此它会带着之前的完整上下文继续。

```json
{
  "task": "Continue where we left off — fix the remaining test failures",
  "runtime": "acp",
  "agentId": "codex",
  "resumeSessionId": "<previous-session-id>"
}
```

常见用例：

- 将 Codex 会话从笔记本电脑移交到手机 — 让你的代理从你离开的地方继续
- 继续你在 CLI 中交互式开始的编码会话，现在通过代理无头运行
- 接续因网关重启或空闲超时而中断的工作

注意事项：

- `resumeSessionId` 需要 `runtime: "acp"` — 与子代理运行时一起使用时返回错误。
- `resumeSessionId` 恢复上游 ACP 对话历史；`thread` 和 `mode` 仍然正常适用于你正在创建的新 OpenClaw 会话，因此 `mode: "session"` 仍然需要 `thread: true`。
- 目标代理必须支持 `session/load`（Codex 和 Claude Code 支持）。
- 如果未找到会话 ID，创建将失败并返回明确错误 — 不会静默回退到新会话。

### 操作者冒烟测试

在网关部署后使用此方法进行快速在线检查，验证 ACP 创建确实端到端工作，而不仅仅是通过单元测试。

推荐的验证步骤：

1. 验证目标主机上已部署的网关版本/提交。
2. 确认已部署的源代码包含 `src/gateway/sessions-patch.ts` 中的 ACP 血统接受（`subagent:* or acp:* sessions`）。
3. 打开一个临时 ACPX 桥接会话连接到在线代理（例如 `jpclawhq` 上的 `razor(main)`）。
4. 要求该代理使用以下参数调用 `sessions_spawn`：
   - `runtime: "acp"`
   - `agentId: "codex"`
   - `mode: "run"`
   - task：`Reply with exactly LIVE-ACP-SPAWN-OK`
5. 验证代理报告：
   - `accepted=yes`
   - 一个真实的 `childSessionKey`
   - 无验证器错误
6. 清理临时 ACPX 桥接会话。

发送给在线代理的示例提示词：

```text
Use the sessions_spawn tool now with runtime: "acp", agentId: "codex", and mode: "run".
Set the task to: "Reply with exactly LIVE-ACP-SPAWN-OK".
Then report only: accepted=<yes/no>; childSessionKey=<value or none>; error=<exact text or none>.
```

注意事项：

- 将此冒烟测试保持在 `mode: "run"` 上，除非你有意测试线程绑定的持久 ACP 会话。
- 基本验证不要求 `streamTo: "parent"`。该路径取决于请求方/会话能力，属于单独的集成检查。
- 将线程绑定的 `mode: "session"` 测试作为第二轮更丰富的集成测试，从真实的 Discord 线程或 Telegram 主题中执行。

## 沙箱兼容性

ACP 会话目前在主机运行时上运行，不在 OpenClaw 沙箱内。

当前限制：

- 如果请求方会话处于沙箱中，`sessions_spawn({ runtime: "acp" })` 和 `/acp spawn` 的 ACP 创建都会被阻止。
  - 错误：`Sandboxed sessions cannot spawn ACP sessions because runtime="acp" runs on the host. Use runtime="subagent" from sandboxed sessions.`
- `sessions_spawn` 附带 `runtime: "acp"` 不支持 `sandbox: "require"`。
  - 错误：`sessions_spawn sandbox="require" is unsupported for runtime="acp" because ACP sessions run outside the sandbox. Use runtime="subagent" or sandbox="inherit".`

当你需要沙箱强制执行时使用 `runtime: "subagent"`。

### 通过 `/acp` 命令

需要从聊天中进行显式操作者控制时使用 `/acp spawn`。

```text
/acp spawn codex --mode persistent --thread auto
/acp spawn codex --mode oneshot --thread off
/acp spawn codex --thread here
```

关键标志：

- `--mode persistent|oneshot`
- `--thread auto|here|off`
- `--cwd <absolute-path>`
- `--label <name>`

参阅[斜杠命令](/tools/slash-commands)。

## 会话目标解析

大多数 `/acp` 操作接受可选的会话目标（`session-key`、`session-id` 或 `session-label`）。

解析顺序：

1. 显式目标参数（或 `/acp steer` 的 `--session`）
   - 先尝试 key
   - 然后尝试 UUID 格式的 session id
   - 然后尝试 label
2. 当前线程绑定（如果当前对话/线程绑定到 ACP 会话）
3. 当前请求方会话回退

如果没有目标解析成功，OpenClaw 返回明确错误（`Unable to resolve session target: ...`）。

## 创建线程模式

`/acp spawn` 支持 `--thread auto|here|off`。

| 模式   | 行为                                                                                               |
| ------ | --------------------------------------------------------------------------------------------------- |
| `auto` | 在活跃线程中：绑定该线程。不在线程中：在支持时创建/绑定子线程。 |
| `here` | 要求当前处于活跃线程中；否则失败。                                                  |
| `off`  | 不绑定。会话以未绑定状态启动。                                                                 |

注意事项：

- 在不支持线程绑定的界面上，默认行为实际上是 `off`。
- 线程绑定创建需要频道策略支持：
  - Discord：`channels.discord.threadBindings.spawnAcpSessions=true`
  - Telegram：`channels.telegram.threadBindings.spawnAcpSessions=true`

## ACP 控制

可用的命令族：

- `/acp spawn`
- `/acp cancel`
- `/acp steer`
- `/acp close`
- `/acp status`
- `/acp set-mode`
- `/acp set`
- `/acp cwd`
- `/acp permissions`
- `/acp timeout`
- `/acp model`
- `/acp reset-options`
- `/acp sessions`
- `/acp doctor`
- `/acp install`

`/acp status` 显示有效的运行时选项，并在可用时同时显示运行时级别和后端级别的会话标识符。

某些控制取决于后端能力。如果后端不支持某个控制，OpenClaw 返回明确的不支持控制错误。

## ACP 命令手册

| 命令                 | 功能                                                      | 示例                                                           |
| -------------------- | --------------------------------------------------------- | -------------------------------------------------------------- |
| `/acp spawn`         | 创建 ACP 会话；可选线程绑定。                             | `/acp spawn codex --mode persistent --thread auto --cwd /repo` |
| `/acp cancel`        | 取消目标会话的进行中轮次。                                | `/acp cancel agent:codex:acp:<uuid>`                           |
| `/acp steer`         | 向运行中的会话发送引导指令。                              | `/acp steer --session support inbox prioritize failing tests`  |
| `/acp close`         | 关闭会话并解除线程目标绑定。                              | `/acp close`                                                   |
| `/acp status`        | 显示后端、模式、状态、运行时选项、能力。                  | `/acp status`                                                  |
| `/acp set-mode`      | 设置目标会话的运行时模式。                                | `/acp set-mode plan`                                           |
| `/acp set`           | 通用运行时配置选项写入。                                  | `/acp set model openai/gpt-5.2`                                |
| `/acp cwd`           | 设置运行时工作目录覆盖。                                  | `/acp cwd /Users/user/Projects/repo`                           |
| `/acp permissions`   | 设置审批策略配置文件。                                    | `/acp permissions strict`                                      |
| `/acp timeout`       | 设置运行时超时（秒）。                                    | `/acp timeout 120`                                             |
| `/acp model`         | 设置运行时模型覆盖。                                      | `/acp model anthropic/claude-opus-4-5`                         |
| `/acp reset-options` | 移除会话运行时选项覆盖。                                  | `/acp reset-options`                                           |
| `/acp sessions`      | 列出存储中最近的 ACP 会话。                               | `/acp sessions`                                                |
| `/acp doctor`        | 后端健康检查、能力查询、可操作的修复建议。                | `/acp doctor`                                                  |
| `/acp install`       | 打印确定性安装和启用步骤。                                | `/acp install`                                                 |

## 运行时选项映射

`/acp` 提供便捷命令和通用设置器。

等价操作：

- `/acp model <id>` 映射到运行时配置键 `model`。
- `/acp permissions <profile>` 映射到运行时配置键 `approval_policy`。
- `/acp timeout <seconds>` 映射到运行时配置键 `timeout`。
- `/acp cwd <path>` 直接更新运行时 cwd 覆盖。
- `/acp set <key> <value>` 是通用路径。
  - 特殊情况：`key=cwd` 使用 cwd 覆盖路径。
- `/acp reset-options` 清除目标会话的所有运行时覆盖。

## acpx 工具支持（当前）

当前 acpx 内置工具别名：

- `pi`
- `claude`
- `codex`
- `opencode`
- `gemini`
- `kimi`

当 OpenClaw 使用 acpx 后端时，除非你的 acpx 配置定义了自定义代理别名，否则建议使用这些值作为 `agentId`。

直接使用 acpx CLI 也可以通过 `--agent <command>` 指定任意适配器，但该原始逃生通道是 acpx CLI 的功能（不是常规的 OpenClaw `agentId` 路径）。

## 必需配置

核心 ACP 基线：

```json5
{
  acp: {
    enabled: true,
    // Optional. Default is true; set false to pause ACP dispatch while keeping /acp controls.
    dispatch: { enabled: true },
    backend: "acpx",
    defaultAgent: "codex",
    allowedAgents: ["pi", "claude", "codex", "opencode", "gemini", "kimi"],
    maxConcurrentSessions: 8,
    stream: {
      coalesceIdleMs: 300,
      maxChunkChars: 1200,
    },
    runtime: {
      ttlMinutes: 120,
    },
  },
}
```

线程绑定配置因频道适配器而异。Discord 示例：

```json5
{
  session: {
    threadBindings: {
      enabled: true,
      idleHours: 24,
      maxAgeHours: 0,
    },
  },
  channels: {
    discord: {
      threadBindings: {
        enabled: true,
        spawnAcpSessions: true,
      },
    },
  },
}
```

如果线程绑定 ACP 创建不工作，请首先验证适配器功能标志：

- Discord：`channels.discord.threadBindings.spawnAcpSessions=true`

参阅[配置参考](/gateway/configuration-reference)。

## acpx 后端的插件设置

安装并启用插件：

```bash
openclaw plugins install acpx
openclaw config set plugins.entries.acpx.enabled true
```

开发期间的本地工作区安装：

```bash
openclaw plugins install ./extensions/acpx
```

然后验证后端健康状态：

```text
/acp doctor
```

### acpx 命令和版本配置

默认情况下，acpx 插件（发布为 `@openclaw/acpx`）使用插件本地固定的二进制文件：

1. 命令默认为 `extensions/acpx/node_modules/.bin/acpx`。
2. 预期版本默认为扩展固定版本。
3. 启动时立即将 ACP 后端注册为未就绪状态。
4. 后台确保任务验证 `acpx --version`。
5. 如果插件本地二进制文件缺失或不匹配，它会运行：
   `npm install --omit=dev --no-save acpx@<pinned>` 并重新验证。

你可以在插件配置中覆盖命令/版本：

```json
{
  "plugins": {
    "entries": {
      "acpx": {
        "enabled": true,
        "config": {
          "command": "../acpx/dist/cli.js",
          "expectedVersion": "any"
        }
      }
    }
  }
}
```

注意事项：

- `command` 接受绝对路径、相对路径或命令名（`acpx`）。
- 相对路径从 OpenClaw 工作区目录解析。
- `expectedVersion: "any"` 禁用严格版本匹配。
- 当 `command` 指向自定义二进制文件/路径时，插件本地自动安装被禁用。
- OpenClaw 启动在后端健康检查运行时保持非阻塞。

参阅[插件](/tools/plugin)。

## 权限配置

ACP 会话以非交互方式运行 — 没有 TTY 来批准或拒绝文件写入和 shell 执行权限提示。acpx 插件提供两个配置键来控制权限处理方式：

### `permissionMode`

控制工具代理可以在不提示的情况下执行哪些操作。

| 值              | 行为                                                      |
| --------------- | --------------------------------------------------------- |
| `approve-all`   | 自动批准所有文件写入和 shell 命令。                       |
| `approve-reads` | 仅自动批准读取；写入和执行需要提示。                      |
| `deny-all`      | 拒绝所有权限提示。                                        |

### `nonInteractivePermissions`

控制当权限提示将被显示但没有可用的交互式 TTY 时会发生什么（ACP 会话始终如此）。

| 值     | 行为                                                              |
| ------ | ----------------------------------------------------------------- |
| `fail` | 以 `AcpRuntimeError` 中止会话。**（默认）**                      |
| `deny` | 静默拒绝权限并继续（优雅降级）。                                  |

### 配置

通过插件配置设置：

```bash
openclaw config set plugins.entries.acpx.config.permissionMode approve-all
openclaw config set plugins.entries.acpx.config.nonInteractivePermissions fail
```

更改这些值后重启网关。

> **重要：** OpenClaw 目前默认为 `permissionMode=approve-reads` 和 `nonInteractivePermissions=fail`。在非交互式 ACP 会话中，任何触发权限提示的写入或执行都可能因 `AcpRuntimeError: Permission prompt unavailable in non-interactive mode` 而失败。
>
> 如果你需要限制权限，请将 `nonInteractivePermissions` 设为 `deny`，使会话优雅降级而非崩溃。

## 故障排查

| 症状                                                                     | 可能原因                                                                        | 修复方法                                                                                                                                                          |
| ------------------------------------------------------------------------ | ------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ACP runtime backend is not configured`                                  | 后端插件缺失或已禁用。                                                          | 安装并启用后端插件，然后运行 `/acp doctor`。                                                                                                                      |
| `ACP is disabled by policy (acp.enabled=false)`                          | ACP 全局禁用。                                                                  | 设置 `acp.enabled=true`。                                                                                                                                         |
| `ACP dispatch is disabled by policy (acp.dispatch.enabled=false)`        | 从普通线程消息的分发被禁用。                                                    | 设置 `acp.dispatch.enabled=true`。                                                                                                                                |
| `ACP agent "<id>" is not allowed by policy`                              | 代理不在允许列表中。                                                            | 使用允许的 `agentId` 或更新 `acp.allowedAgents`。                                                                                                                 |
| `Unable to resolve session target: ...`                                  | 错误的 key/id/label 令牌。                                                      | 运行 `/acp sessions`，复制准确的 key/label，重试。                                                                                                                |
| `--thread here requires running /acp spawn inside an active ... thread`  | 在线程上下文外使用了 `--thread here`。                                          | 移动到目标线程或使用 `--thread auto`/`off`。                                                                                                                      |
| `Only <user-id> can rebind this thread.`                                 | 另一个用户拥有线程绑定。                                                        | 以所有者身份重新绑定或使用不同的线程。                                                                                                                            |
| `Thread bindings are unavailable for <channel>.`                         | 适配器缺少线程绑定能力。                                                        | 使用 `--thread off` 或移动到支持的适配器/频道。                                                                                                                   |
| `Sandboxed sessions cannot spawn ACP sessions ...`                       | ACP 运行时在主机侧；请求方会话处于沙箱中。                                     | 从沙箱会话使用 `runtime="subagent"`，或从非沙箱会话运行 ACP 创建。                                                                                                |
| `sessions_spawn sandbox="require" is unsupported for runtime="acp" ...`  | 为 ACP 运行时请求了 `sandbox="require"`。                                       | 使用 `runtime="subagent"` 进行必需的沙箱化，或从非沙箱会话使用 ACP 附带 `sandbox="inherit"`。                                                                     |
| ACP 绑定会话缺少元数据                                                  | 过期/已删除的 ACP 会话元数据。                                                  | 使用 `/acp spawn` 重新创建，然后重新绑定/聚焦线程。                                                                                                               |
| `AcpRuntimeError: Permission prompt unavailable in non-interactive mode` | `permissionMode` 在非交互式 ACP 会话中阻止了写入/执行。                         | 将 `plugins.entries.acpx.config.permissionMode` 设为 `approve-all` 并重启网关。参阅[权限配置](#权限配置)。                                                        |
| ACP 会话提前失败且输出很少                                               | 权限提示被 `permissionMode`/`nonInteractivePermissions` 阻止。                  | 检查网关日志中的 `AcpRuntimeError`。要获取完全权限，设置 `permissionMode=approve-all`；要优雅降级，设置 `nonInteractivePermissions=deny`。                         |
| ACP 会话在完成工作后无限期停滞                                           | 工具进程已完成但 ACP 会话未报告完成。                                           | 使用 `ps aux \| grep acpx` 监控；手动终止过期进程。                                                                                                               |
