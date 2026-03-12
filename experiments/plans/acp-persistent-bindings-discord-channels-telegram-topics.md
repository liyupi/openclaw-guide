# ACP Persistent Bindings for Discord Channels and Telegram Topics

状态：草案

## 概述

引入持久化 ACP 绑定，将以下内容映射：

- Discord 频道（以及需要时的现有线程），和
- Telegram 群组/超级群组中的论坛主题（`chatId:topic:topicId`）

到长期存活的 ACP 会话，绑定状态存储在顶层 `bindings[]` 条目中，使用显式绑定类型。

这使得高流量消息频道中的 ACP 使用变得可预测且持久，用户可以创建专用频道/主题，如 `codex`、`claude-1` 或 `claude-myrepo`。

## 动机

当前基于线程的 ACP 行为针对临时 Discord 线程工作流进行了优化。Telegram 没有相同的线程模型；它在群组/超级群组中使用论坛主题。用户希望在聊天界面中拥有稳定的、始终在线的 ACP "工作区"，而不仅仅是临时线程会话。

## 目标

- 支持持久化 ACP 绑定：
  - Discord 频道/线程
  - Telegram 论坛主题（群组/超级群组）
- 使绑定的权威来源由配置驱动。
- 保持 `/acp`、`/new`、`/reset`、`/focus` 和消息投递行为在 Discord 和 Telegram 之间一致。
- 保留现有的临时绑定流程用于临时使用。

## 非目标

- 完全重新设计 ACP 运行时/会话内部机制。
- 移除现有的临时绑定流程。
- 在第一次迭代中扩展到所有频道。
- 在此阶段实现 Telegram 频道私信主题（`direct_messages_topic_id`）。
- 在此阶段实现 Telegram 私聊主题变体。

## 用户体验方向

### 1）两种绑定类型

- **持久绑定**：保存在配置中，启动时协调，用于"命名工作区"频道/主题。
- **临时绑定**：仅在运行时存在，按空闲/最大存活时间策略过期。

### 2）命令行为

- `/acp spawn ... --thread here|auto|off` 仍然可用。
- 添加显式绑定生命周期控制：
  - `/acp bind [session|agent] [--persist]`
  - `/acp unbind [--persist]`
  - `/acp status` 包含绑定是 `persistent` 还是 `temporary` 的信息。
- 在已绑定的对话中，`/new` 和 `/reset` 会就地重置已绑定的 ACP 会话，并保持绑定关系。

### 3）对话标识

- 使用规范对话 ID：
  - Discord：频道/线程 ID。
  - Telegram 主题：`chatId:topic:topicId`。
- 绝不以单独的主题 ID 作为 Telegram 绑定的键。

## 配置模型（提案）

在顶层 `bindings[]` 中统一路由和持久化 ACP 绑定配置，使用显式 `type` 鉴别器：

```jsonc
{
  "agents": {
    "list": [
      {
        "id": "main",
        "default": true,
        "workspace": "~/.openclaw/workspace-main",
        "runtime": { "type": "embedded" },
      },
      {
        "id": "codex",
        "workspace": "~/.openclaw/workspace-codex",
        "runtime": {
          "type": "acp",
          "acp": {
            "agent": "codex",
            "backend": "acpx",
            "mode": "persistent",
            "cwd": "/workspace/repo-a",
          },
        },
      },
      {
        "id": "claude",
        "workspace": "~/.openclaw/workspace-claude",
        "runtime": {
          "type": "acp",
          "acp": {
            "agent": "claude",
            "backend": "acpx",
            "mode": "persistent",
            "cwd": "/workspace/repo-b",
          },
        },
      },
    ],
  },
  "acp": {
    "enabled": true,
    "backend": "acpx",
    "allowedAgents": ["codex", "claude"],
  },
  "bindings": [
    // Route bindings (existing behavior)
    {
      "type": "route",
      "agentId": "main",
      "match": { "channel": "discord", "accountId": "default" },
    },
    {
      "type": "route",
      "agentId": "main",
      "match": { "channel": "telegram", "accountId": "default" },
    },
    // Persistent ACP conversation bindings
    {
      "type": "acp",
      "agentId": "codex",
      "match": {
        "channel": "discord",
        "accountId": "default",
        "peer": { "kind": "channel", "id": "222222222222222222" },
      },
      "acp": {
        "label": "codex-main",
        "mode": "persistent",
        "cwd": "/workspace/repo-a",
        "backend": "acpx",
      },
    },
    {
      "type": "acp",
      "agentId": "claude",
      "match": {
        "channel": "discord",
        "accountId": "default",
        "peer": { "kind": "channel", "id": "333333333333333333" },
      },
      "acp": {
        "label": "claude-repo-b",
        "mode": "persistent",
        "cwd": "/workspace/repo-b",
      },
    },
    {
      "type": "acp",
      "agentId": "codex",
      "match": {
        "channel": "telegram",
        "accountId": "default",
        "peer": { "kind": "group", "id": "-1001234567890:topic:42" },
      },
      "acp": {
        "label": "tg-codex-42",
        "mode": "persistent",
      },
    },
  ],
  "channels": {
    "discord": {
      "guilds": {
        "111111111111111111": {
          "channels": {
            "222222222222222222": {
              "enabled": true,
              "requireMention": false,
            },
            "333333333333333333": {
              "enabled": true,
              "requireMention": false,
            },
          },
        },
      },
    },
    "telegram": {
      "groups": {
        "-1001234567890": {
          "topics": {
            "42": {
              "requireMention": false,
            },
          },
        },
      },
    },
  },
}
```

### 最小示例（无逐绑定 ACP 覆盖）

```jsonc
{
  "agents": {
    "list": [
      { "id": "main", "default": true, "runtime": { "type": "embedded" } },
      {
        "id": "codex",
        "runtime": {
          "type": "acp",
          "acp": { "agent": "codex", "backend": "acpx", "mode": "persistent" },
        },
      },
      {
        "id": "claude",
        "runtime": {
          "type": "acp",
          "acp": { "agent": "claude", "backend": "acpx", "mode": "persistent" },
        },
      },
    ],
  },
  "acp": { "enabled": true, "backend": "acpx" },
  "bindings": [
    {
      "type": "route",
      "agentId": "main",
      "match": { "channel": "discord", "accountId": "default" },
    },
    {
      "type": "route",
      "agentId": "main",
      "match": { "channel": "telegram", "accountId": "default" },
    },

    {
      "type": "acp",
      "agentId": "codex",
      "match": {
        "channel": "discord",
        "accountId": "default",
        "peer": { "kind": "channel", "id": "222222222222222222" },
      },
    },
    {
      "type": "acp",
      "agentId": "claude",
      "match": {
        "channel": "discord",
        "accountId": "default",
        "peer": { "kind": "channel", "id": "333333333333333333" },
      },
    },
    {
      "type": "acp",
      "agentId": "codex",
      "match": {
        "channel": "telegram",
        "accountId": "default",
        "peer": { "kind": "group", "id": "-1009876543210:topic:5" },
      },
    },
  ],
}
```

说明：

- `bindings[].type` 是显式的：
  - `route`：正常的代理路由。
  - `acp`：为匹配的对话绑定持久化 ACP 运行环境。
- 对于 `type: "acp"`，`match.peer.id` 是规范对话键：
  - Discord 频道/线程：原始频道/线程 ID。
  - Telegram 主题：`chatId:topic:topicId`。
- `bindings[].acp.backend` 是可选的。后端回退顺序：
  1. `bindings[].acp.backend`
  2. `agents.list[].runtime.acp.backend`
  3. 全局 `acp.backend`
- `mode`、`cwd` 和 `label` 遵循相同的覆盖模式（`绑定覆盖 -> 代理运行时默认值 -> 全局/默认行为`）。
- 保留现有的 `session.threadBindings.*` 和 `channels.discord.threadBindings.*` 用于临时绑定策略。
- 持久化条目声明期望状态；运行时协调到实际的 ACP 会话/绑定。
- 每个对话节点一个活跃 ACP 绑定是预期的模型。
- 向后兼容：缺少 `type` 的条目对于旧条目解释为 `route`。

### 后端选择

- ACP 会话初始化在 spawn 期间已使用配置的后端选择（目前为 `acp.backend`）。
- 此提案扩展了 spawn/协调逻辑，优先使用类型化 ACP 绑定覆盖：
  - `bindings[].acp.backend` 用于对话级别的覆盖。
  - `agents.list[].runtime.acp.backend` 用于每代理的默认值。
- 如果不存在覆盖，保持当前行为（`acp.backend` 默认值）。

## 在当前系统中的架构适配

### 复用现有组件

- `SessionBindingService` 已支持跨频道的对话引用。
- ACP spawn/bind 流程已通过服务 API 支持绑定。
- Telegram 已通过 `MessageThreadId` 和 `chatId` 携带主题/线程上下文。

### 新增/扩展的组件

- **Telegram 绑定适配器**（与 Discord 适配器并行）：
  - 为每个 Telegram 账号注册适配器，
  - 通过规范对话 ID 进行解析/列出/绑定/解绑/触碰。
- **类型化绑定解析器/索引**：
  - 将 `bindings[]` 拆分为 `route` 和 `acp` 视图，
  - 仅在 `route` 绑定上保持 `resolveAgentRoute`，
  - 仅从 `acp` 绑定解析持久化 ACP 意图。
- **Telegram 入站绑定解析**：
  - 在路由最终确定前解析已绑定的会话（Discord 已经这样做了）。
- **持久绑定协调器**：
  - 启动时：加载配置的顶层 `type: "acp"` 绑定，确保 ACP 会话存在，确保绑定存在。
  - 配置变更时：安全地应用差异。
- **切换模型**：
  - 不读取频道本地的 ACP 绑定回退，
  - 持久化 ACP 绑定仅从顶层 `bindings[].type="acp"` 条目获取。

## 分阶段交付

### 第一阶段：类型化绑定模式基础

- 扩展配置模式以支持 `bindings[].type` 鉴别器：
  - `route`，
  - `acp`，带有可选的 `acp` 覆盖对象（`mode`、`backend`、`cwd`、`label`）。
- 扩展代理模式，使用运行时描述符标记 ACP 原生代理（`agents.list[].runtime.type`）。
- 添加路由与 ACP 绑定的解析器/索引拆分。

### 第二阶段：运行时解析 + Discord/Telegram 对等

- 从顶层 `type: "acp"` 条目解析持久化 ACP 绑定，适用于：
  - Discord 频道/线程，
  - Telegram 论坛主题（`chatId:topic:topicId` 规范 ID）。
- 实现 Telegram 绑定适配器和入站绑定会话覆盖，与 Discord 对等。
- 此阶段不包含 Telegram 私信/私聊主题变体。

### 第三阶段：命令对等和重置

- 对齐已绑定的 Telegram/Discord 对话中 `/acp`、`/new`、`/reset` 和 `/focus` 的行为。
- 确保绑定在配置的重置流程中存活。

### 第四阶段：加固

- 更好的诊断（`/acp status`、启动协调日志）。
- 冲突处理和健康检查。

## 防护措施和策略

- 严格遵守 ACP 启用和沙箱限制，与当前完全一致。
- 保持显式账户范围（`accountId`）以避免跨账户泄漏。
- 在路由模糊时采用失败关闭策略。
- 保持每个频道配置中的提及/访问策略行为显式化。

## 测试计划

- 单元测试：
  - 对话 ID 规范化（特别是 Telegram 主题 ID），
  - 协调器的创建/更新/删除路径，
  - `/acp bind --persist` 和解绑流程。
- 集成测试：
  - 入站 Telegram 主题 -> 已绑定 ACP 会话解析，
  - 入站 Discord 频道/线程 -> 持久绑定优先级。
- 回归测试：
  - 临时绑定继续工作，
  - 未绑定的频道/主题保持当前路由行为。

## 开放问题

- 在 Telegram 主题中 `/acp spawn --thread auto` 是否应默认为 `here`？
- 持久绑定是否应始终在已绑定的对话中绕过提及门控，还是需要显式的 `requireMention=false`？
- `/focus` 是否应获得 `--persist` 作为 `/acp bind --persist` 的别名？

## 上线计划

- 作为按对话选择加入的方式发布（存在 `bindings[].type="acp"` 条目即可）。
- 先从 Discord + Telegram 开始。
- 添加包含以下示例的文档：
  - "每个代理一个频道/主题"
  - "同一代理的多个频道/主题使用不同的 `cwd`"
  - "团队命名模式（`codex-1`、`claude-repo-x`）"。
