---
summary: "提案：ACP 绑定对话的长期命令授权模型"
read_when:
  - 设计 Telegram/Discord ACP 绑定频道/主题中的原生命令授权行为时
title: "ACP Bound Command Authorization (Proposal)"
---

# ACP 绑定命令授权（提案）

状态：已提出，**尚未实现**。

本文档描述了 ACP 绑定对话中原生命令的长期授权模型。这是一个实验性提案，不替代当前的生产行为。

关于已实现的行为，请阅读以下源代码和测试：

- `src/telegram/bot-native-commands.ts`
- `src/discord/monitor/native-command.ts`
- `src/auto-reply/reply/commands-core.ts`

## 问题

目前我们有针对特定命令的检查（例如 `/new` 和 `/reset`），这些检查需要在 ACP 绑定的频道/主题中即使允许列表为空也能工作。这解决了直接的用户体验痛点，但基于命令名称的例外不具备可扩展性。

## 长期形态

将命令授权从临时的处理器逻辑移至命令元数据加共享策略评估器。

### 1）向命令定义添加授权策略元数据

每个命令定义应声明一个授权策略。示例形状：

```ts
type CommandAuthPolicy =
  | { mode: "owner_or_allowlist" } // 默认，当前的严格行为
  | { mode: "bound_acp_or_owner_or_allowlist" } // 在显式绑定的 ACP 对话中允许
  | { mode: "owner_only" };
```

`/new` 和 `/reset` 将使用 `bound_acp_or_owner_or_allowlist`。
大多数其他命令将保持 `owner_or_allowlist`。

### 2）跨频道共享一个评估器

引入一个辅助函数，使用以下内容评估命令授权：

- 命令策略元数据
- 发送方授权状态
- 已解析的对话绑定状态

Telegram 和 Discord 原生处理器都应调用相同的辅助函数以避免行为偏差。

### 3）使用绑定匹配作为绕过边界

当策略允许绑定 ACP 绕过时，仅在当前对话解析到已配置的绑定匹配时授权（而非仅因为当前会话键看起来像 ACP）。

这保持边界显式并最小化意外扩大的风险。

## 为何更好

- 可扩展到未来的命令，无需添加更多命令名称条件判断。
- 保持跨频道的行为一致性。
- 通过要求显式绑定匹配保留当前安全模型。
- 保持允许列表为可选加固而非普遍要求。

## 上线计划（未来）

1. 向命令注册表类型和命令数据添加命令授权策略字段。
2. 实现共享评估器并迁移 Telegram + Discord 原生处理器。
3. 将 `/new` 和 `/reset` 移至元数据驱动的策略。
4. 为每种策略模式和频道界面添加测试。

## 非目标

- 此提案不更改 ACP 会话生命周期行为。
- 此提案不要求所有 ACP 绑定命令都有允许列表。
- 此提案不更改现有的路由绑定语义。

## 说明

此提案故意是增量式的，不删除或替换现有的实验文档。
