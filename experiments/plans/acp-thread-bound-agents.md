---
summary: "通过核心中的一等 ACP 控制平面和插件支持的运行时（首先是 acpx）集成 ACP 编码代理"
owner: "onutc"
status: "draft"
last_updated: "2026-02-25"
title: "ACP Thread Bound Agents"
---

# ACP 线程绑定代理

## 概述

此计划定义了 OpenClaw 如何在支持线程的频道中（首先是 Discord）支持 ACP 编码代理，具有生产级的生命周期和恢复能力。

相关文档：

- [统一运行时流式重构计划](/experiments/plans/acp-unified-streaming-refactor)

目标用户体验：

- 用户将 ACP 会话派生或聚焦到线程中
- 该线程中的用户消息路由到已绑定的 ACP 会话
- 代理输出流式返回到同一线程身份
- 会话可以是持久的或一次性的，并具有显式清理控制

## 决策摘要

长期推荐是混合架构：

- OpenClaw 核心拥有 ACP 控制平面关注点
  - 会话标识和元数据
  - 线程绑定和路由决策
  - 投递不变量和重复抑制
  - 生命周期清理和恢复语义
- ACP 运行时后端是可插拔的
  - 第一个后端是基于 acpx 的插件服务
  - 运行时处理 ACP 传输、队列、取消、重连

OpenClaw 不应在核心中重新实现 ACP 传输内部机制。
OpenClaw 不应依赖纯插件拦截路径进行路由。

## 北极星架构（终极目标）

将 ACP 作为 OpenClaw 的一等控制平面，配合可插拔的运行时适配器。

不可协商的不变量：

- 每个 ACP 线程绑定引用一个有效的 ACP 会话记录
- 每个 ACP 会话具有显式生命周期状态（`creating`、`idle`、`running`、`cancelling`、`closed`、`error`）
- 每个 ACP 运行具有显式运行状态（`queued`、`running`、`completed`、`failed`、`cancelled`）
- spawn、bind 和初始入队是原子的
- 命令重试是幂等的（无重复运行或重复 Discord 输出）
- 绑定线程的频道输出是 ACP 运行事件的投影，绝不是临时副作用

长期所有权模型：

- `AcpSessionManager` 是唯一的 ACP 写入器和编排器
- 管理器首先位于网关进程中；以后可以通过相同接口移到专用 sidecar
- 每个 ACP 会话键，管理器拥有一个内存中的 actor（序列化命令执行）
- 适配器（`acpx`、未来的后端）仅是传输/运行时实现

长期持久化模型：

- 将 ACP 控制平面状态移至 OpenClaw 状态目录下的专用 SQLite 存储（WAL 模式）
- 在迁移期间保留 `SessionEntry.acp` 作为兼容性投影，而非权威来源
- 以追加方式存储 ACP 事件以支持重放、崩溃恢复和确定性投递

### 投递策略（通往终极目标的桥梁）

- 短期桥梁
  - 保留当前线程绑定机制和现有 ACP 配置表面
  - 修复元数据缺口 bug 并通过单一核心 ACP 分支路由 ACP 轮次
  - 立即添加幂等键和失败关闭路由检查
- 长期切换
  - 将 ACP 权威来源移至控制平面数据库 + actor
  - 使绑定线程投递纯粹基于事件投影
  - 移除依赖于机会性会话条目元数据的旧版回退行为

## 为何不纯插件方案

当前插件钩子不足以在没有核心变更的情况下实现端到端 ACP 会话路由。

- 从线程绑定到入站路由首先在核心调度中解析为会话键
- 消息钩子是发射后不管的，无法短路主回复路径
- 插件命令适用于控制操作，但不适用于替换核心的每轮次调度流程

结论：

- ACP 运行时可以插件化
- ACP 路由分支必须存在于核心中

## 现有基础设施的复用

已实现且应保持为规范的：

- 线程绑定目标支持 `subagent` 和 `acp`
- 入站线程路由覆盖在正常调度前通过绑定解析
- 通过 webhook 的出站线程身份在回复投递中
- `/focus` 和 `/unfocus` 流程与 ACP 目标兼容
- 带启动恢复的持久绑定存储
- 在存档、删除、取消聚焦、重置和删除时的解绑生命周期

此计划扩展该基础而非替换它。

## 架构

### 边界模型

核心（必须在 OpenClaw 核心中）：

- 回复管道中的 ACP 会话模式调度分支
- 避免父频道加线程重复的投递仲裁
- ACP 控制平面持久化（在迁移期间带 `SessionEntry.acp` 兼容性投影）
- 与会话重置/删除相关的生命周期解绑和运行时分离语义

插件后端（acpx 实现）：

- ACP 运行时 Worker 监督
- acpx 进程调用和事件解析
- ACP 命令处理器（`/acp ...`）和操作员用户体验
- 后端特定的配置默认值和诊断

### 运行时所有权模型

- 一个网关进程拥有 ACP 编排状态
- ACP 执行在通过 acpx 后端的受监督子进程中运行
- 进程策略是按活跃 ACP 会话键长期存活的，而非按消息

这避免了每次提示时的启动成本，并使取消和重连语义可靠。

### 核心运行时契约

添加核心 ACP 运行时契约，使路由代码不依赖于 CLI 细节，并可在不更改调度逻辑的情况下切换后端：

```ts
export type AcpRuntimePromptMode = "prompt" | "steer";

export type AcpRuntimeHandle = {
  sessionKey: string;
  backend: string;
  runtimeSessionName: string;
};

export type AcpRuntimeEvent =
  | { type: "text_delta"; stream: "output" | "thought"; text: string }
  | { type: "tool_call"; name: string; argumentsText: string }
  | { type: "done"; usage?: Record<string, number> }
  | { type: "error"; code: string; message: string; retryable?: boolean };

export interface AcpRuntime {
  ensureSession(input: {
    sessionKey: string;
    agent: string;
    mode: "persistent" | "oneshot";
    cwd?: string;
    env?: Record<string, string>;
    idempotencyKey: string;
  }): Promise<AcpRuntimeHandle>;

  submit(input: {
    handle: AcpRuntimeHandle;
    text: string;
    mode: AcpRuntimePromptMode;
    idempotencyKey: string;
  }): Promise<{ runtimeRunId: string }>;

  stream(input: {
    handle: AcpRuntimeHandle;
    runtimeRunId: string;
    onEvent: (event: AcpRuntimeEvent) => Promise<void> | void;
    signal?: AbortSignal;
  }): Promise<void>;

  cancel(input: {
    handle: AcpRuntimeHandle;
    runtimeRunId?: string;
    reason?: string;
    idempotencyKey: string;
  }): Promise<void>;

  close(input: { handle: AcpRuntimeHandle; reason: string; idempotencyKey: string }): Promise<void>;

  health?(): Promise<{ ok: boolean; details?: string }>;
}
```

实现细节：

- 第一个后端：`AcpxRuntime` 作为插件服务发布
- 核心通过注册表解析运行时，当没有 ACP 运行时后端可用时返回显式的操作员错误

### 控制平面数据模型和持久化

长期权威来源是专用 ACP SQLite 数据库（WAL 模式），用于事务性更新和崩溃安全恢复：

- `acp_sessions`
  - `session_key`（主键）、`backend`、`agent`、`mode`、`cwd`、`state`、`created_at`、`updated_at`、`last_error`
- `acp_runs`
  - `run_id`（主键）、`session_key`（外键）、`state`、`requester_message_id`、`idempotency_key`、`started_at`、`ended_at`、`error_code`、`error_message`
- `acp_bindings`
  - `binding_key`（主键）、`thread_id`、`channel_id`、`account_id`、`session_key`（外键）、`expires_at`、`bound_at`
- `acp_events`
  - `event_id`（主键）、`run_id`（外键）、`seq`、`kind`、`payload_json`、`created_at`
- `acp_delivery_checkpoint`
  - `run_id`（主键/外键）、`last_event_seq`、`last_discord_message_id`、`updated_at`
- `acp_idempotency`
  - `scope`、`idempotency_key`、`result_json`、`created_at`，唯一约束 `(scope, idempotency_key)`

```ts
export type AcpSessionMeta = {
  backend: string;
  agent: string;
  runtimeSessionName: string;
  mode: "persistent" | "oneshot";
  cwd?: string;
  state: "idle" | "running" | "error";
  lastActivityAt: number;
  lastError?: string;
};
```

存储规则：

- 在迁移期间保留 `SessionEntry.acp` 作为兼容性投影
- 进程 ID 和 socket 仅保留在内存中
- 持久化生命周期和运行状态存储在 ACP 数据库中，而非通用会话 JSON 中
- 如果运行时所有者终止，网关从 ACP 数据库重新水合并从检查点恢复

### 路由和投递

入站：

- 保留当前线程绑定查找作为第一路由步骤
- 如果绑定目标是 ACP 会话，路由到 ACP 运行时分支而非 `getReplyFromConfig`
- 显式的 `/acp steer` 命令使用 `mode: "steer"`

出站：

- ACP 事件流被规范化为 OpenClaw 回复块
- 投递目标通过现有的绑定目标路径解析
- 当该会话轮次存在活跃的绑定线程时，父频道的完成被抑制

流式策略：

- 使用合并窗口流式输出部分内容
- 可配置的最小间隔和最大块字节数以保持在 Discord 速率限制内
- 完成或失败时始终发出最终消息

### 状态机和事务边界

会话状态机：

- `creating -> idle -> running -> idle`
- `running -> cancelling -> idle | error`
- `idle -> closed`
- `error -> idle | closed`

运行状态机：

- `queued -> running -> completed`
- `running -> failed | cancelled`
- `queued -> cancelled`

必需的事务边界：

- spawn 事务
  - 创建 ACP 会话行
  - 创建/更新 ACP 线程绑定行
  - 排入初始运行行
- close 事务
  - 标记会话关闭
  - 删除/过期绑定行
  - 写入最终关闭事件
- cancel 事务
  - 用幂等键标记目标运行为 cancelling/cancelled

这些边界不允许部分成功。

### 每会话 Actor 模型

`AcpSessionManager` 为每个 ACP 会话键运行一个 actor：

- actor 邮箱序列化 `submit`、`cancel`、`close` 和 `stream` 副作用
- actor 拥有该会话的运行时句柄水合和运行时适配器进程生命周期
- actor 在任何 Discord 投递之前按顺序（`seq`）写入运行事件
- actor 在成功的出站发送后更新投递检查点

这消除了跨轮次竞争并防止重复或乱序的线程输出。

### 幂等性和投递投影

所有外部 ACP 操作必须携带幂等键：

- spawn 幂等键
- prompt/steer 幂等键
- cancel 幂等键
- close 幂等键

投递规则：

- Discord 消息从 `acp_events` 加 `acp_delivery_checkpoint` 派生
- 重试从检查点恢复，不重新发送已投递的块
- 每次运行的最终回复发出由投影逻辑保证恰好一次

### 恢复和自愈

网关启动时：

- 加载非终态 ACP 会话（`creating`、`idle`、`running`、`cancelling`、`error`）
- 在首次入站事件时惰性重建 actor 或在配置上限下积极重建
- 协调任何缺少心跳的 `running` 运行并标记 `failed` 或通过适配器恢复

入站 Discord 线程消息时：

- 如果绑定存在但 ACP 会话缺失，以显式的过期绑定消息失败关闭
- 可选地在操作员安全验证后自动解绑过期绑定
- 绝不将过期 ACP 绑定静默路由到正常 LLM 路径

### 生命周期和安全

支持的操作：

- 取消当前运行：`/acp cancel`
- 解绑线程：`/unfocus`
- 关闭 ACP 会话：`/acp close`
- 按有效 TTL 自动关闭空闲会话

TTL 策略：

- 有效 TTL 是以下值的最小值
  - 全局/会话 TTL
  - Discord 线程绑定 TTL
  - ACP 运行时所有者 TTL

安全控制：

- 按名称允许列表 ACP 代理
- 限制 ACP 会话的工作区根目录
- 环境变量允许列表透传
- 每账户和全局最大并发 ACP 会话数
- 运行时崩溃的有界重启退避

## 配置表面

核心键：

- `acp.enabled`
- `acp.dispatch.enabled`（独立的 ACP 路由禁止开关）
- `acp.backend`（默认 `acpx`）
- `acp.defaultAgent`
- `acp.allowedAgents[]`
- `acp.maxConcurrentSessions`
- `acp.stream.coalesceIdleMs`
- `acp.stream.maxChunkChars`
- `acp.runtime.ttlMinutes`
- `acp.controlPlane.store`（默认 `sqlite`）
- `acp.controlPlane.storePath`
- `acp.controlPlane.recovery.eagerActors`
- `acp.controlPlane.recovery.reconcileRunningAfterMs`
- `acp.controlPlane.checkpoint.flushEveryEvents`
- `acp.controlPlane.checkpoint.flushEveryMs`
- `acp.idempotency.ttlHours`
- `channels.discord.threadBindings.spawnAcpSessions`

插件/后端键（acpx 插件部分）：

- 后端命令/路径覆盖
- 后端环境变量允许列表
- 后端每代理预设
- 后端启动/停止超时
- 后端每会话最大进行中运行数

## 实现规范

### 控制平面模块（新增）

在核心中添加专用 ACP 控制平面模块：

- `src/acp/control-plane/manager.ts`
  - 拥有 ACP actor、生命周期转换、命令序列化
- `src/acp/control-plane/store.ts`
  - SQLite 模式管理、事务、查询辅助函数
- `src/acp/control-plane/events.ts`
  - 类型化 ACP 事件定义和序列化
- `src/acp/control-plane/checkpoint.ts`
  - 持久化投递检查点和重放游标
- `src/acp/control-plane/idempotency.ts`
  - 幂等键预留和响应重放
- `src/acp/control-plane/recovery.ts`
  - 启动时协调和 actor 重新水合计划

兼容性桥接模块：

- `src/acp/runtime/session-meta.ts`
  - 暂时保留用于投影到 `SessionEntry.acp`
  - 迁移切换后必须停止作为权威来源

### 必需的不变量（必须在代码中强制执行）

- ACP 会话创建和线程绑定是原子的（单一事务）
- 每个 ACP 会话 actor 同一时间最多有一个活跃运行
- 事件 `seq` 在每次运行中严格递增
- 投递检查点永远不会超过最后提交的事件
- 对于重复命令键的幂等重放返回先前的成功负载
- 过期/缺失的 ACP 元数据不能路由到正常的非 ACP 回复路径

### 核心接触点

需要更改的核心文件：

- `src/auto-reply/reply/dispatch-from-config.ts`
  - ACP 分支调用 `AcpSessionManager.submit` 和事件投影投递
  - 移除绕过控制平面不变量的直接 ACP 回退
- `src/auto-reply/reply/inbound-context.ts`（或最近的规范化上下文边界）
  - 为 ACP 控制平面暴露规范化的路由键和幂等种子
- `src/config/sessions/types.ts`
  - 保留 `SessionEntry.acp` 作为仅投影的兼容性字段
- `src/gateway/server-methods/sessions.ts`
  - reset/delete/archive 必须调用 ACP 管理器的 close/unbind 事务路径
- `src/infra/outbound/bound-delivery-router.ts`
  - 对 ACP 绑定会话轮次强制执行失败关闭的目标行为
- `src/discord/monitor/thread-bindings.ts`
  - 添加连接到控制平面查找的 ACP 过期绑定验证辅助函数
- `src/auto-reply/reply/commands-acp.ts`
  - 通过 ACP 管理器 API 路由 spawn/cancel/close/steer
- `src/agents/acp-spawn.ts`
  - 停止临时元数据写入；调用 ACP 管理器 spawn 事务
- `src/plugin-sdk/**` 和插件运行时桥接
  - 清晰地暴露 ACP 后端注册和健康语义

明确不替换的核心文件：

- `src/discord/monitor/message-handler.preflight.ts`
  - 保留线程绑定覆盖行为作为规范会话键解析器

### ACP 运行时注册表 API

添加核心注册表模块：

- `src/acp/runtime/registry.ts`

必需的 API：

```ts
export type AcpRuntimeBackend = {
  id: string;
  runtime: AcpRuntime;
  healthy?: () => boolean;
};

export function registerAcpRuntimeBackend(backend: AcpRuntimeBackend): void;
export function unregisterAcpRuntimeBackend(id: string): void;
export function getAcpRuntimeBackend(id?: string): AcpRuntimeBackend | null;
export function requireAcpRuntimeBackend(id?: string): AcpRuntimeBackend;
```

行为：

- `requireAcpRuntimeBackend` 在不可用时抛出类型化的 ACP 后端缺失错误
- 插件服务在 `start` 时注册后端并在 `stop` 时注销
- 运行时查找是只读的且进程本地的

### acpx 运行时插件契约（实现细节）

对于第一个生产后端（`extensions/acpx`），OpenClaw 和 acpx 通过严格的命令契约连接：

- 后端 ID：`acpx`
- 插件服务 ID：`acpx-runtime`
- 运行时句柄编码：`runtimeSessionName = acpx:v1:<base64url(json)>`
- 编码负载字段：
  - `name`（acpx 命名会话；使用 OpenClaw `sessionKey`）
  - `agent`（acpx 代理命令）
  - `cwd`（会话工作区根目录）
  - `mode`（`persistent | oneshot`）

命令映射：

- 确保会话：
  - `acpx --format json --json-strict --cwd <cwd> <agent> sessions ensure --name <name>`
- 提示轮次：
  - `acpx --format json --json-strict --cwd <cwd> <agent> prompt --session <name> --file -`
- 取消：
  - `acpx --format json --json-strict --cwd <cwd> <agent> cancel --session <name>`
- 关闭：
  - `acpx --format json --json-strict --cwd <cwd> <agent> sessions close <name>`

流式传输：

- OpenClaw 从 `acpx --format json --json-strict` 消费 ndjson 事件
- `text` => `text_delta/output`
- `thought` => `text_delta/thought`
- `tool_call` => `tool_call`
- `done` => `done`
- `error` => `error`

### 会话模式补丁

在 `src/config/sessions/types.ts` 中补丁 `SessionEntry`：

```ts
type SessionAcpMeta = {
  backend: string;
  agent: string;
  runtimeSessionName: string;
  mode: "persistent" | "oneshot";
  cwd?: string;
  state: "idle" | "running" | "error";
  lastActivityAt: number;
  lastError?: string;
};
```

持久化字段：

- `SessionEntry.acp?: SessionAcpMeta`

迁移规则：

- 阶段 A：双写（`acp` 投影 + ACP SQLite 权威来源）
- 阶段 B：主读 ACP SQLite，回退读旧版 `SessionEntry.acp`
- 阶段 C：迁移命令从有效旧版条目回填缺失的 ACP 行
- 阶段 D：移除回退读取并保留投影仅用于用户体验
- 旧版字段（`cliSessionIds`、`claudeCliSessionId`）保持不变

### 错误契约

添加稳定的 ACP 错误码和面向用户的消息：

- `ACP_BACKEND_MISSING`
  - 消息：`ACP runtime backend is not configured. Install and enable the acpx runtime plugin.`
- `ACP_BACKEND_UNAVAILABLE`
  - 消息：`ACP runtime backend is currently unavailable. Try again in a moment.`
- `ACP_SESSION_INIT_FAILED`
  - 消息：`Could not initialize ACP session runtime.`
- `ACP_TURN_FAILED`
  - 消息：`ACP turn failed before completion.`

规则：

- 在线程中返回可操作的用户安全消息
- 仅在运行时日志中记录详细的后端/系统错误
- 当 ACP 路由被显式选择时，绝不静默回退到正常 LLM 路径

### 重复投递仲裁

ACP 绑定轮次的单一路由规则：

- 如果目标 ACP 会话和请求者上下文存在活跃线程绑定，仅投递到该绑定线程
- 不对同一轮次也发送到父频道
- 如果绑定目标选择不明确，以显式错误失败关闭（无隐式父频道回退）
- 如果不存在活跃绑定，使用正常会话目标行为

### 可观测性和运营就绪

必需的指标：

- 按后端和错误码的 ACP spawn 成功/失败计数
- ACP 运行延迟百分位数（队列等待、运行时轮次时间、投递投影时间）
- ACP actor 重启计数和重启原因
- 过期绑定检测计数
- 幂等重放命中率
- Discord 投递重试和速率限制计数器

必需的日志：

- 按 `sessionKey`、`runId`、`backend`、`threadId`、`idempotencyKey` 键控的结构化日志
- 会话和运行状态机的显式状态转换日志
- 带脱敏安全参数和退出摘要的适配器命令日志

必需的诊断：

- `/acp sessions` 包含状态、活跃运行、最后错误和绑定状态
- `/acp doctor`（或等效命令）验证后端注册、存储健康和过期绑定

### 配置优先级和有效值

ACP 启用优先级：

- 账户覆盖：`channels.discord.accounts.<id>.threadBindings.spawnAcpSessions`
- 频道覆盖：`channels.discord.threadBindings.spawnAcpSessions`
- 全局 ACP 门控：`acp.enabled`
- 调度门控：`acp.dispatch.enabled`
- 后端可用性：`acp.backend` 的已注册后端

自动启用行为：

- 当 ACP 已配置时（`acp.enabled=true`、`acp.dispatch.enabled=true` 或 `acp.backend=acpx`），插件自动启用将 `plugins.entries.acpx.enabled=true` 标记，除非被拒绝列表或显式禁用

TTL 有效值：

- `min(session ttl, discord thread binding ttl, acp runtime ttl)`

### 测试映射

单元测试：

- `src/acp/runtime/registry.test.ts`（新增）
- `src/auto-reply/reply/dispatch-from-config.acp.test.ts`（新增）
- `src/infra/outbound/bound-delivery-router.test.ts`（扩展 ACP 失败关闭用例）
- `src/config/sessions/types.test.ts` 或最近的会话存储测试（ACP 元数据持久化）

集成测试：

- `src/discord/monitor/reply-delivery.test.ts`（绑定 ACP 投递目标行为）
- `src/discord/monitor/message-handler.preflight*.test.ts`（绑定 ACP 会话键路由连续性）
- acpx 插件运行时测试在后端包中（服务注册/启动/停止 + 事件规范化）

网关端到端测试：

- `src/gateway/server.sessions.gateway-server-sessions-a.e2e.test.ts`（扩展 ACP reset/delete 生命周期覆盖）
- ACP 线程轮次端到端往返：spawn、消息、流式传输、取消、unfocus、重启恢复

### 上线保护

添加独立的 ACP 调度禁止开关：

- `acp.dispatch.enabled` 首次发布默认为 `false`
- 禁用时：
  - ACP spawn/focus 控制命令仍可绑定会话
  - ACP 调度路径不激活
  - 用户收到显式消息表示 ACP 调度被策略禁用
- 金丝雀验证后，可在后续版本中将默认值翻转为 `true`

## 命令和用户体验计划

### 新命令

- `/acp spawn <agent-id> [--mode persistent|oneshot] [--thread auto|here|off]`
- `/acp cancel [session]`
- `/acp steer <instruction>`
- `/acp close [session]`
- `/acp sessions`

### 现有命令兼容性

- `/focus <sessionKey>` 继续支持 ACP 目标
- `/unfocus` 保持当前语义
- `/session idle` 和 `/session max-age` 替换旧的 TTL 覆盖

## 分阶段上线

### 第 0 阶段 ADR 和模式冻结

- 发布 ACP 控制平面所有权和适配器边界的 ADR
- 冻结数据库模式（`acp_sessions`、`acp_runs`、`acp_bindings`、`acp_events`、`acp_delivery_checkpoint`、`acp_idempotency`）
- 定义稳定的 ACP 错误码、事件契约和状态转换守卫

### 第 1 阶段 核心中的控制平面基础

- 实现 `AcpSessionManager` 和每会话 actor 运行时
- 实现 ACP SQLite 存储和事务辅助函数
- 实现幂等性存储和重放辅助函数
- 实现事件追加 + 投递检查点模块
- 将 spawn/cancel/close API 连接到带事务保证的管理器

### 第 2 阶段 核心路由和生命周期集成

- 从调度管道将线程绑定的 ACP 轮次路由到 ACP 管理器
- 当 ACP 绑定/会话不变量失败时强制执行失败关闭路由
- 将 reset/delete/archive/unfocus 生命周期与 ACP close/unbind 事务集成
- 添加过期绑定检测和可选的自动解绑策略

### 第 3 阶段 acpx 后端适配器/插件

- 按运行时契约实现 `acpx` 适配器（`ensureSession`、`submit`、`stream`、`cancel`、`close`）
- 添加后端健康检查和启动/拆卸注册
- 将 acpx ndjson 事件规范化为 ACP 运行时事件
- 强制执行后端超时、进程监督和重启/退避策略

### 第 4 阶段 投递投影和频道用户体验（首先 Discord）

- 实现带检查点恢复的事件驱动频道投影（首先 Discord）
- 使用速率限制感知的刷新策略合并流式块
- 保证每次运行恰好一次的最终完成消息
- 发布 `/acp spawn`、`/acp cancel`、`/acp steer`、`/acp close`、`/acp sessions`

### 第 5 阶段 迁移和切换

- 引入到 `SessionEntry.acp` 投影加 ACP SQLite 权威来源的双写
- 添加旧版 ACP 元数据行的迁移工具
- 将读取路径翻转为 ACP SQLite 主路径
- 移除依赖缺失 `SessionEntry.acp` 的旧版回退路由

### 第 6 阶段 加固、SLO 和规模限制

- 强制执行并发限制（全局/账户/会话）、队列策略和超时预算
- 添加完整的遥测、仪表盘和告警阈值
- 混沌测试崩溃恢复和重复投递抑制
- 发布后端故障、数据库损坏和过期绑定修复的运行手册

### 完整实现清单

- 核心控制平面模块和测试
- 数据库迁移和回滚计划
- 跨调度和命令的 ACP 管理器 API 集成
- 插件运行时桥接中的适配器注册接口
- acpx 适配器实现和测试
- 带检查点重放的线程支持频道投递投影逻辑（首先 Discord）
- reset/delete/archive/unfocus 的生命周期钩子
- 过期绑定检测器和面向操作员的诊断
- 所有新 ACP 键的配置验证和优先级测试
- 运营文档和故障排除运行手册

## 测试计划

单元测试：

- ACP 数据库事务边界（spawn/bind/enqueue 原子性、cancel、close）
- 会话和运行的 ACP 状态机转换守卫
- 所有 ACP 命令的幂等预留/重放语义
- 每会话 actor 序列化和队列排序
- acpx 事件解析器和块合并器
- 运行时监督器重启和退避策略
- 配置优先级和有效 TTL 计算
- 当后端/会话无效时核心 ACP 路由分支选择和失败关闭行为

集成测试：

- 用于确定性流式传输和取消行为的假 ACP 适配器进程
- 带事务持久化的 ACP 管理器 + 调度集成
- 线程绑定入站路由到 ACP 会话键
- 线程绑定出站投递抑制父频道重复
- 检查点重放在投递失败后恢复并从最后事件继续
- 插件服务注册和 ACP 运行时后端的拆卸

网关端到端测试：

- spawn ACP 并创建线程，交换多轮提示，unfocus
- 使用持久化 ACP 数据库和绑定重启网关，然后继续同一会话
- 多线程中的并发 ACP 会话无串扰
- 重复命令重试（相同幂等键）不创建重复运行或回复
- 过期绑定场景产生显式错误和可选的自动清理行为

## 风险和缓解措施

- 过渡期间的重复投递
  - 缓解：单一目标解析器和幂等事件检查点
- 负载下的运行时进程波动
  - 缓解：每会话长期存活的所有者 + 并发上限 + 退避
- 插件缺失或配置错误
  - 缓解：显式的面向操作员的错误和失败关闭的 ACP 路由（不隐式回退到正常会话路径）
- 子代理和 ACP 门控之间的配置混淆
  - 缓解：显式的 ACP 键和包含有效策略来源的命令反馈
- 控制平面存储损坏或迁移 bug
  - 缓解：WAL 模式、备份/恢复钩子、迁移冒烟测试和只读回退诊断
- Actor 死锁或邮箱饥饿
  - 缓解：看门狗计时器、actor 健康探针和带拒绝遥测的有界邮箱深度

## 验收清单

- ACP 会话 spawn 可以在支持的频道适配器中创建或绑定线程（目前为 Discord）
- 所有线程消息仅路由到绑定的 ACP 会话
- ACP 输出以流式或批量方式出现在同一线程身份中
- 绑定轮次不在父频道中产生重复输出
- spawn+bind+初始入队在持久化存储中是原子的
- ACP 命令重试是幂等的，不重复运行或输出
- cancel、close、unfocus、archive、reset 和 delete 执行确定性清理
- 崩溃重启保留映射并恢复多轮连续性
- 并发线程绑定的 ACP 会话独立工作
- ACP 后端缺失状态产生清晰的可操作错误
- 过期绑定被检测并显式展示（带可选的安全自动清理）
- 控制平面指标和诊断可供操作员使用
- 新的单元、集成和端到端覆盖通过

## 附录：当前实现的定向重构（状态）

这些是非阻塞的后续工作，用于在当前功能集着陆后保持 ACP 路径的可维护性。

### 1）集中 ACP 调度策略评估（已完成）

- 通过 `src/acp/policy.ts` 中的共享 ACP 策略辅助函数实现
- 调度、ACP 命令生命周期处理器和 ACP spawn 路径现在消费共享策略逻辑

### 2）按子命令域拆分 ACP 命令处理器（已完成）

- `src/auto-reply/reply/commands-acp.ts` 现在是一个薄路由器
- 子命令行为拆分为：
  - `src/auto-reply/reply/commands-acp/lifecycle.ts`
  - `src/auto-reply/reply/commands-acp/runtime-options.ts`
  - `src/auto-reply/reply/commands-acp/diagnostics.ts`
  - `src/auto-reply/reply/commands-acp/shared.ts` 中的共享辅助函数

### 3）按职责拆分 ACP 会话管理器（已完成）

- 管理器拆分为：
  - `src/acp/control-plane/manager.ts`（公共门面 + 单例）
  - `src/acp/control-plane/manager.core.ts`（管理器实现）
  - `src/acp/control-plane/manager.types.ts`（管理器类型/依赖）
  - `src/acp/control-plane/manager.utils.ts`（规范化 + 辅助函数）

### 4）可选的 acpx 运行时适配器清理

- `extensions/acpx/src/runtime.ts` 可拆分为：
- 进程执行/监督
- ndjson 事件解析/规范化
- 运行时 API 表面（`submit`、`cancel`、`close` 等）
- 提高可测试性并使后端行为更容易审计
