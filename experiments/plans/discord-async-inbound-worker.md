---
summary: "将 Discord 网关监听器与长时间运行的代理轮次解耦，使用 Discord 专用入站 Worker 的状态和后续步骤"
owner: "openclaw"
status: "in_progress"
last_updated: "2026-03-05"
title: "Discord Async Inbound Worker Plan"
---

# Discord 异步入站 Worker 计划

## 目标

通过使入站 Discord 轮次异步化，消除 Discord 监听器超时作为面向用户的故障模式：

1. 网关监听器快速接受并规范化入站事件。
2. Discord 运行队列使用与当前相同的排序边界键存储序列化任务。
3. Worker 在 Carbon 监听器生命周期之外执行实际的代理轮次。
4. 运行完成后将回复投递回原始频道或线程。

这是排队的 Discord 运行在 `channels.discord.eventQueue.listenerTimeout` 处超时而代理运行本身仍在进行中这一问题的长期修复方案。

## 当前状态

此计划已部分实现。

已完成：

- Discord 监听器超时和 Discord 运行超时现在是独立的设置。
- 已接受的入站 Discord 轮次被排入 `src/discord/monitor/inbound-worker.ts`。
- Worker 现在拥有长时间运行的轮次，而非 Carbon 监听器。
- 现有的每路由排序通过队列键保留。
- 存在针对 Discord Worker 路径的超时回归覆盖测试。

用通俗的话说：

- 生产环境的超时 bug 已修复
- 长时间运行的轮次不再仅因 Discord 监听器预算到期而终止
- Worker 架构尚未完成

仍然缺少的：

- `DiscordInboundJob` 仍然只是部分规范化，且仍携带活跃运行时引用
- 命令语义（`stop`、`new`、`reset`、未来的会话控制）尚未完全 Worker 原生化
- Worker 可观测性和运营状态仍然很少
- 仍然没有重启持久性

## 存在原因

当前行为将完整的代理轮次绑定到监听器生命周期：

- `src/discord/monitor/listeners.ts` 应用超时和中止边界。
- `src/discord/monitor/message-handler.ts` 将排队的运行保持在该边界内。
- `src/discord/monitor/message-handler.process.ts` 在行内执行媒体加载、路由、调度、打字指示器、草稿流式传输和最终回复投递。

该架构有两个不良属性：

- 长时间但健康的轮次可能被监听器看门狗中止
- 即使下游运行时会产生回复，用户也可能看不到回复

提高超时时间有帮助但不改变故障模式。

## 非目标

- 在此轮中不重新设计非 Discord 频道。
- 在第一次实现中不将其扩展为通用的全频道 Worker 框架。
- 暂不提取共享的跨频道入站 Worker 抽象；仅在重复明显时共享低级原语。
- 在第一轮中不添加持久化崩溃恢复，除非安全着陆需要。
- 在此计划中不更改路由选择、绑定语义或 ACP 策略。

## 当前约束

当前 Discord 处理路径仍然依赖一些活跃运行时对象，这些不应留在长期任务负载中：

- Carbon `Client`
- 原始 Discord 事件形状
- 内存中的公会历史映射
- 线程绑定管理器回调
- 活跃的打字指示器和草稿流状态

我们已将执行移至 Worker 队列，但规范化边界仍然不完整。目前 Worker 是"在同一进程中稍后运行，并使用某些相同的活跃对象"，而非完全的纯数据任务边界。

## 目标架构

### 1. 监听器阶段

`DiscordMessageListener` 仍然是入口点，但其职责变为：

- 运行预检和策略检查
- 将已接受的输入规范化为可序列化的 `DiscordInboundJob`
- 将任务排入按会话或按频道的异步队列
- 一旦排队成功立即返回到 Carbon

监听器不应再拥有端到端的 LLM 轮次生命周期。

### 2. 规范化的任务负载

引入一个可序列化的任务描述符，仅包含稍后运行轮次所需的数据。

最小形状：

- 路由标识
  - `agentId`
  - `sessionKey`
  - `accountId`
  - `channel`
- 投递标识
  - 目标频道 ID
  - 回复目标消息 ID
  - 线程 ID（如果存在）
- 发送方标识
  - 发送方 ID、标签、用户名、标记
- 频道上下文
  - 公会 ID
  - 频道名称或 slug
  - 线程元数据
  - 已解析的系统提示覆盖
- 规范化的消息正文
  - 基础文本
  - 有效消息文本
  - 附件描述符或已解析的媒体引用
- 门控决策
  - 提及要求结果
  - 命令授权结果
  - 已绑定的会话或代理元数据（如适用）

任务负载不得包含活跃的 Carbon 对象或可变闭包。

当前实现状态：

- 部分完成
- `src/discord/monitor/inbound-job.ts` 存在并定义了 Worker 交接
- 负载仍包含活跃的 Discord 运行时上下文，应进一步精简

### 3. Worker 阶段

添加一个 Discord 专用的 Worker 运行器，负责：

- 从 `DiscordInboundJob` 重建轮次上下文
- 加载媒体和运行所需的任何额外频道元数据
- 调度代理轮次
- 投递最终回复负载
- 更新状态和诊断

推荐位置：

- `src/discord/monitor/inbound-worker.ts`
- `src/discord/monitor/inbound-job.ts`

### 4. 排序模型

对于给定的路由边界，排序必须保持与当前等效。

推荐键：

- 使用与 `resolveDiscordRunQueueKey(...)` 相同的队列键逻辑

这保留了现有行为：

- 一个已绑定的代理对话不会与自身交错
- 不同的 Discord 频道仍可独立处理

### 5. 超时模型

切换后，有两个独立的超时类别：

- 监听器超时
  - 仅覆盖规范化和排队
  - 应该很短
- 运行超时
  - 可选的、Worker 拥有的、显式的、用户可见的
  - 不应从 Carbon 监听器设置中意外继承

这消除了"Discord 网关监听器保持存活"与"代理运行健康"之间的当前意外耦合。

## 推荐实现阶段

### 第一阶段：规范化边界

- 状态：部分实现
- 已完成：
  - 提取了 `buildDiscordInboundJob(...)`
  - 添加了 Worker 交接测试
- 剩余：
  - 使 `DiscordInboundJob` 成为纯数据
  - 将活跃运行时依赖移至 Worker 拥有的服务，而非每任务负载
  - 停止通过将活跃监听器引用拼接回任务来重建处理上下文

### 第二阶段：内存 Worker 队列

- 状态：已实现
- 已完成：
  - 添加了按已解析运行队列键索引的 `DiscordInboundWorkerQueue`
  - 监听器排队任务而非直接等待 `processDiscordMessage(...)`
  - Worker 在进程内、仅在内存中执行任务

这是第一个功能性切换。

### 第三阶段：进程拆分

- 状态：未开始
- 将投递、打字指示器和草稿流式传输的所有权移至 Worker 面向的适配器之后。
- 用 Worker 上下文重建替换对活跃预检上下文的直接使用。
- 如需要可暂时保留 `processDiscordMessage(...)` 作为门面，然后拆分它。

### 第四阶段：命令语义

- 状态：未开始
  确保在工作排队时原生 Discord 命令仍然正确运行：

- `stop`
- `new`
- `reset`
- 任何未来的会话控制命令

Worker 队列必须暴露足够的运行状态，以便命令可以定位活跃或排队的轮次。

### 第五阶段：可观测性和运营用户体验

- 状态：未开始
- 将队列深度和活跃 Worker 计数发送到监控状态
- 记录排队时间、开始时间、完成时间、超时或取消原因
- 在日志中清晰地展示 Worker 拥有的超时或投递故障

### 第六阶段：可选的持久性后续

- 状态：未开始
  仅在内存版本稳定后：

- 决定排队的 Discord 任务是否应在网关重启后存活
- 如果是，持久化任务描述符和投递检查点
- 如果否，明确记录内存边界

除非着陆需要重启恢复，否则这应该是单独的后续工作。

## 文件影响

当前主要文件：

- `src/discord/monitor/listeners.ts`
- `src/discord/monitor/message-handler.ts`
- `src/discord/monitor/message-handler.preflight.ts`
- `src/discord/monitor/message-handler.process.ts`
- `src/discord/monitor/status.ts`

当前 Worker 文件：

- `src/discord/monitor/inbound-job.ts`
- `src/discord/monitor/inbound-worker.ts`
- `src/discord/monitor/inbound-job.test.ts`
- `src/discord/monitor/message-handler.queue.test.ts`

可能的下一个接触点：

- `src/auto-reply/dispatch.ts`
- `src/discord/monitor/reply-delivery.ts`
- `src/discord/monitor/thread-bindings.ts`
- `src/discord/monitor/native-command.ts`

## 当前下一步

下一步是使 Worker 边界成为真实的，而非部分的。

接下来做这些：

1. 将活跃运行时依赖从 `DiscordInboundJob` 中移出
2. 将这些依赖保留在 Discord Worker 实例上
3. 将排队任务精简为纯 Discord 特定数据：
   - 路由标识
   - 投递目标
   - 发送方信息
   - 规范化的消息快照
   - 门控和绑定决策
4. 在 Worker 内部从该纯数据重建 Worker 执行上下文

实际上，这意味着：

- `client`
- `threadBindings`
- `guildHistories`
- `discordRestFetch`
- 其他可变的仅运行时句柄

应该停止存在于每个排队任务上，而是存在于 Worker 本身或 Worker 拥有的适配器之后。

完成后，下一个后续应该是 `stop`、`new` 和 `reset` 的命令状态清理。

## 测试计划

保留现有的超时重现覆盖在：

- `src/discord/monitor/message-handler.queue.test.ts`

添加新测试：

1. 监听器在排队后返回，无需等待完整轮次
2. 保持每路由排序
3. 不同频道仍可并发运行
4. 回复投递到原始消息目标
5. `stop` 取消 Worker 拥有的活跃运行
6. Worker 失败产生可见的诊断信息而不阻塞后续任务
7. ACP 绑定的 Discord 频道在 Worker 执行下仍正确路由

## 风险和缓解措施

- 风险：命令语义偏离当前同步行为
  缓解：在同一次切换中着陆命令状态管道，而非之后

- 风险：回复投递丢失线程或回复目标上下文
  缓解：使投递标识成为 `DiscordInboundJob` 中的一等公民

- 风险：重试或队列重启期间的重复发送
  缓解：第一轮保持仅内存，或在持久化前添加显式投递幂等性

- 风险：迁移期间 `message-handler.process.ts` 变得更难理解
  缓解：在 Worker 切换之前或期间将其拆分为规范化、执行和投递辅助函数

## 验收标准

当以下条件满足时计划完成：

1. Discord 监听器超时不再中止健康的长时间运行轮次。
2. 监听器生命周期和代理轮次生命周期在代码中是独立的概念。
3. 现有的每会话排序得到保留。
4. ACP 绑定的 Discord 频道通过相同的 Worker 路径工作。
5. `stop` 定位 Worker 拥有的运行，而非旧的监听器拥有的调用栈。
6. 超时和投递失败成为显式的 Worker 结果，而非静默的监听器丢弃。

## 剩余着陆策略

在后续 PR 中完成：

1. 使 `DiscordInboundJob` 成为纯数据并将活跃运行时引用移至 Worker
2. 清理 `stop`、`new` 和 `reset` 的命令状态所有权
3. 添加 Worker 可观测性和运营状态
4. 决定是否需要持久性或明确记录内存边界

如果保持仅限 Discord 且继续避免过早的跨频道 Worker 抽象，这仍然是有界的后续工作。
