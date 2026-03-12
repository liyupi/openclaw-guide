---
summary: "跨频道会话绑定架构和第一次迭代交付范围"
read_when:
  - 重构跨频道会话路由和绑定时
  - 调查跨频道的重复、过期或缺失会话投递时
owner: "onutc"
status: "in-progress"
last_updated: "2026-02-21"
title: "Session Binding Channel Agnostic Plan"
---

# 跨频道会话绑定计划

## 概述

本文档定义了长期的跨频道会话绑定模型以及下一次实现迭代的具体范围。

目标：

- 使子代理绑定会话路由成为核心能力
- 将频道特定行为保留在适配器中
- 避免正常 Discord 行为的回归

## 存在原因

当前行为混合了：

- 完成内容策略
- 目标路由策略
- Discord 特定细节

这导致了如下边缘情况：

- 并发运行下主频道和线程的重复投递
- 复用绑定管理器时的过期令牌使用
- webhook 发送缺少活动记账

## 第一次迭代范围

此迭代故意受限。

### 1. 添加跨频道核心接口

添加核心类型和服务接口用于绑定和路由。

提议的核心类型：

```ts
export type BindingTargetKind = "subagent" | "session";
export type BindingStatus = "active" | "ending" | "ended";

export type ConversationRef = {
  channel: string;
  accountId: string;
  conversationId: string;
  parentConversationId?: string;
};

export type SessionBindingRecord = {
  bindingId: string;
  targetSessionKey: string;
  targetKind: BindingTargetKind;
  conversation: ConversationRef;
  status: BindingStatus;
  boundAt: number;
  expiresAt?: number;
  metadata?: Record<string, unknown>;
};
```

核心服务契约：

```ts
export interface SessionBindingService {
  bind(input: {
    targetSessionKey: string;
    targetKind: BindingTargetKind;
    conversation: ConversationRef;
    metadata?: Record<string, unknown>;
    ttlMs?: number;
  }): Promise<SessionBindingRecord>;

  listBySession(targetSessionKey: string): SessionBindingRecord[];
  resolveByConversation(ref: ConversationRef): SessionBindingRecord | null;
  touch(bindingId: string, at?: number): void;
  unbind(input: {
    bindingId?: string;
    targetSessionKey?: string;
    reason: string;
  }): Promise<SessionBindingRecord[]>;
}
```

### 2. 添加一个核心投递路由器用于子代理完成

添加单一的完成事件目标解析路径。

路由器契约：

```ts
export interface BoundDeliveryRouter {
  resolveDestination(input: {
    eventKind: "task_completion";
    targetSessionKey: string;
    requester?: ConversationRef;
    failClosed: boolean;
  }): {
    binding: SessionBindingRecord | null;
    mode: "bound" | "fallback";
    reason: string;
  };
}
```

本迭代中：

- 仅 `task_completion` 通过此新路径路由
- 其他事件类型的现有路径保持不变

### 3. 保持 Discord 作为适配器

Discord 仍然是第一个适配器实现。

适配器职责：

- 创建/复用线程对话
- 通过 webhook 或频道发送绑定消息
- 验证线程状态（已存档/已删除）
- 映射适配器元数据（webhook 身份、线程 ID）

### 4. 修复当前已知的正确性问题

本迭代中必需的：

- 复用现有线程绑定管理器时刷新令牌使用
- 记录基于 webhook 的 Discord 发送的出站活动
- 当会话模式完成选择了绑定线程目标时，停止隐式的主频道回退

### 5. 保留当前运行时安全默认值

对禁用线程绑定 spawn 的用户无行为变更。

默认值保持：

- `channels.discord.threadBindings.spawnSubagentSessions = false`

结果：

- 正常 Discord 用户保持当前行为
- 新核心路径仅影响启用了绑定会话完成路由的场景

## 不在第一次迭代中

明确延迟：

- ACP 绑定目标（`targetKind: "acp"`）
- Discord 之外的新频道适配器
- 全局替换所有投递路径（`spawn_ack`、未来的 `subagent_message`）
- 协议级别变更
- 所有绑定持久化的存储迁移/版本重设计

关于 ACP 的说明：

- 接口设计为 ACP 留有空间
- ACP 实现不在本迭代中启动

## 路由不变量

这些不变量在第一次迭代中是强制性的。

- 目标选择和内容生成是分开的步骤
- 如果会话模式完成解析到活跃的绑定目标，投递必须目标该目标
- 不从绑定目标到主频道的隐式重路由
- 回退行为必须显式且可观察

## 兼容性和上线

兼容性目标：

- 对关闭线程绑定 spawn 的用户无回归
- 本迭代中不更改非 Discord 频道

上线步骤：

1. 在当前功能门控后着陆接口和路由器。
2. 通过路由器路由 Discord 完成模式绑定投递。
3. 保留旧版路径用于非绑定流程。
4. 使用定向测试和金丝雀运行时日志验证。

## 第一次迭代中必需的测试

单元和集成覆盖必需的：

- 管理器令牌轮换在管理器复用后使用最新令牌
- webhook 发送更新频道活动时间戳
- 同一请求方频道中两个活跃的绑定会话不重复到主频道
- 绑定会话模式运行的完成仅解析到线程目标
- 禁用 spawn 标志保持旧版行为不变

## 提议的实现文件

核心：

- `src/infra/outbound/session-binding-service.ts`（新增）
- `src/infra/outbound/bound-delivery-router.ts`（新增）
- `src/agents/subagent-announce.ts`（完成目标解析集成）

Discord 适配器和运行时：

- `src/discord/monitor/thread-bindings.manager.ts`
- `src/discord/monitor/reply-delivery.ts`
- `src/discord/send.outbound.ts`

测试：

- `src/discord/monitor/provider*.test.ts`
- `src/discord/monitor/reply-delivery.test.ts`
- `src/agents/subagent-announce.format.test.ts`

## 第一次迭代完成标准

- 核心接口存在并已连接用于完成路由
- 上述正确性修复已合并并附带测试
- 会话模式绑定运行中无主频道和线程的重复完成投递
- 禁用绑定 spawn 的部署无行为变更
- ACP 保持明确延迟
