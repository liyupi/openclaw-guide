---
summary: "具有最高代码行数削减潜力的重构集群"
read_when:
  - 希望在不改变行为的情况下减少总代码行数时
  - 选择下一个去重或提取轮次时
title: "Refactor Cluster Backlog"
---

# 重构集群待办

按可能的代码行数削减、安全性和广度排名。

## 1. 频道插件配置和安全脚手架

最高价值集群。

多个频道插件中的重复形状：

- `config.listAccountIds`
- `config.resolveAccount`
- `config.defaultAccountId`
- `config.setAccountEnabled`
- `config.deleteAccount`
- `config.describeAccount`
- `security.resolveDmPolicy`

典型示例：

- `extensions/telegram/src/channel.ts`
- `extensions/googlechat/src/channel.ts`
- `extensions/slack/src/channel.ts`
- `extensions/discord/src/channel.ts`
- `extensions/matrix/src/channel.ts`
- `extensions/irc/src/channel.ts`
- `extensions/signal/src/channel.ts`
- `extensions/mattermost/src/channel.ts`

可能的提取形状：

- `buildChannelConfigAdapter(...)`
- `buildMultiAccountConfigAdapter(...)`
- `buildDmSecurityAdapter(...)`

预期节省：

- ~250-450 行代码

风险：

- 中等。每个频道有略微不同的 `isConfigured`、警告和规范化。

## 2. 扩展运行时单例模板

非常安全。

几乎每个扩展都有相同的运行时持有者：

- `let runtime: PluginRuntime | null = null`
- `setXRuntime`
- `getXRuntime`

典型示例：

- `extensions/telegram/src/runtime.ts`
- `extensions/matrix/src/runtime.ts`
- `extensions/slack/src/runtime.ts`
- `extensions/discord/src/runtime.ts`
- `extensions/whatsapp/src/runtime.ts`
- `extensions/imessage/src/runtime.ts`
- `extensions/twitch/src/runtime.ts`

特殊变体：

- `extensions/bluebubbles/src/runtime.ts`
- `extensions/line/src/runtime.ts`
- `extensions/synology-chat/src/runtime.ts`

可能的提取形状：

- `createPluginRuntimeStore<T>(errorMessage)`

预期节省：

- ~180-260 行代码

风险：

- 低

## 3. 引导提示和配置补丁步骤

大面积覆盖。

许多引导文件重复：

- 解析账户 ID
- 提示允许列表条目
- 合并 allowFrom
- 设置私信策略
- 提示密钥
- 补丁顶层 vs 账户范围配置

典型示例：

- `extensions/bluebubbles/src/onboarding.ts`
- `extensions/googlechat/src/onboarding.ts`
- `extensions/msteams/src/onboarding.ts`
- `extensions/zalo/src/onboarding.ts`
- `extensions/zalouser/src/onboarding.ts`
- `extensions/nextcloud-talk/src/onboarding.ts`
- `extensions/matrix/src/onboarding.ts`
- `extensions/irc/src/onboarding.ts`

现有辅助接缝：

- `src/channels/plugins/onboarding/helpers.ts`

可能的提取形状：

- `promptAllowFromList(...)`
- `buildDmPolicyAdapter(...)`
- `applyScopedAccountPatch(...)`
- `promptSecretFields(...)`

预期节省：

- ~300-600 行代码

风险：

- 中等。容易过度泛化；保持辅助函数窄小且可组合。

## 4. 多账户配置模式片段

跨扩展的重复模式片段。

常见模式：

- `const allowFromEntry = z.union([z.string(), z.number()])`
- 账户模式加：
  - `accounts: z.object({}).catchall(accountSchema).optional()`
  - `defaultAccount: z.string().optional()`
- 重复的私信/群组字段
- 重复的 markdown/工具策略字段

典型示例：

- `extensions/bluebubbles/src/config-schema.ts`
- `extensions/zalo/src/config-schema.ts`
- `extensions/zalouser/src/config-schema.ts`
- `extensions/matrix/src/config-schema.ts`
- `extensions/nostr/src/config-schema.ts`

可能的提取形状：

- `AllowFromEntrySchema`
- `buildMultiAccountChannelSchema(accountSchema)`
- `buildCommonDmGroupFields(...)`

预期节省：

- ~120-220 行代码

风险：

- 低到中等。某些模式简单，某些特殊。

## 5. Webhook 和监控生命周期启动

良好的中等价值集群。

重复的 `startAccount` / 监控设置模式：

- 解析账户
- 计算 webhook 路径
- 记录启动日志
- 启动监控
- 等待中止
- 清理
- 状态汇更新

典型示例：

- `extensions/googlechat/src/channel.ts`
- `extensions/bluebubbles/src/channel.ts`
- `extensions/zalo/src/channel.ts`
- `extensions/telegram/src/channel.ts`
- `extensions/nextcloud-talk/src/channel.ts`

现有辅助接缝：

- `src/plugin-sdk/channel-lifecycle.ts`

可能的提取形状：

- 账户监控生命周期辅助函数
- 基于 webhook 的账户启动辅助函数

预期节省：

- ~150-300 行代码

风险：

- 中到高。传输细节很快出现分歧。

## 6. 小型精确克隆清理

低风险清理桶。

示例：

- 重复的网关 argv 检测：
  - `src/infra/gateway-lock.ts`
  - `src/cli/daemon-cli/lifecycle.ts`
- 重复的端口诊断渲染：
  - `src/cli/daemon-cli/restart-health.ts`
- 重复的会话键构造：
  - `src/web/auto-reply/monitor/broadcast.ts`

预期节省：

- ~30-60 行代码

风险：

- 低

## 测试集群

### LINE webhook 事件固件

典型示例：

- `src/line/bot-handlers.test.ts`

可能的提取：

- `makeLineEvent(...)`
- `runLineEvent(...)`
- `makeLineAccount(...)`

预期节省：

- ~120-180 行代码

### Telegram 原生命令授权矩阵

典型示例：

- `src/telegram/bot-native-commands.group-auth.test.ts`
- `src/telegram/bot-native-commands.plugin-auth.test.ts`

可能的提取：

- 论坛上下文构建器
- 拒绝消息断言辅助函数
- 表驱动授权用例

预期节省：

- ~80-140 行代码

### Zalo 生命周期设置

典型示例：

- `extensions/zalo/src/monitor.lifecycle.test.ts`

可能的提取：

- 共享监控设置测试工具

预期节省：

- ~50-90 行代码

### Brave llm-context 不支持选项测试

典型示例：

- `src/agents/tools/web-tools.enabled-defaults.test.ts`

可能的提取：

- `it.each(...)` 矩阵

预期节省：

- ~30-50 行代码

## 建议顺序

1. 运行时单例模板
2. 小型精确克隆清理
3. 配置和安全构建器提取
4. 测试辅助函数提取
5. 引导步骤提取
6. 监控生命周期辅助函数提取
