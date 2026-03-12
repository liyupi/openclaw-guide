---
summary: "计划：使用 CDP 将浏览器 act:evaluate 从 Playwright 队列中隔离，具有端到端截止时间和更安全的引用解析"
read_when:
  - 处理浏览器 `act:evaluate` 超时、中止或队列阻塞问题时
  - 规划基于 CDP 的 evaluate 执行隔离时
owner: "openclaw"
status: "draft"
last_updated: "2026-02-10"
title: "Browser Evaluate CDP Refactor"
---

# 浏览器 Evaluate CDP 重构计划

## 背景

`act:evaluate` 在页面中执行用户提供的 JavaScript。目前它通过 Playwright（`page.evaluate` 或 `locator.evaluate`）运行。Playwright 按页面序列化 CDP 命令，因此卡住或长时间运行的 evaluate 会阻塞页面命令队列，使该标签页上的所有后续操作看起来"卡住"。

PR #13498 添加了一个务实的安全网（有界 evaluate、中止传播和尽力恢复）。本文档描述了一个更大的重构，使 `act:evaluate` 从本质上与 Playwright 隔离，使卡住的 evaluate 无法阻塞正常的 Playwright 操作。

## 目标

- `act:evaluate` 不能永久阻塞同一标签页上的后续浏览器操作。
- 超时是端到端的唯一事实来源，调用方可以依赖于一个预算。
- 中止和超时在 HTTP 和进程内调度中以相同方式处理。
- 支持 evaluate 的元素定位，而无需将所有内容都从 Playwright 切换出去。
- 保持对现有调用方和负载的向后兼容性。

## 非目标

- 用 CDP 实现替换所有浏览器操作（click、type、wait 等）。
- 移除 PR #13498 中引入的现有安全网（它仍然是有用的回退）。
- 引入超出现有 `browser.evaluateEnabled` 门控的新不安全功能。
- 为 evaluate 添加进程隔离（工作进程/线程）。如果此重构后仍出现难以恢复的卡住状态，这是后续方案。

## 当前架构（为何会卡住）

总体来说：

- 调用方向浏览器控制服务发送 `act:evaluate`。
- 路由处理器调用 Playwright 执行 JavaScript。
- Playwright 序列化页面命令，因此永不结束的 evaluate 会阻塞队列。
- 被阻塞的队列意味着该标签页上后续的 click/type/wait 操作可能看起来挂起。

## 提案架构

### 1. 截止时间传播

引入单一预算概念并从中派生所有内容：

- 调用方设置 `timeoutMs`（或未来的截止时间）。
- 外层请求超时、路由处理器逻辑和页面内的执行预算都使用相同的预算，并在需要时为序列化开销留出少量余量。
- 中止作为 `AbortSignal` 在所有位置传播，以保证取消的一致性。

实现方向：

- 添加一个小型辅助函数（例如 `createBudget({ timeoutMs, signal })`），返回：
  - `signal`：链接的 AbortSignal
  - `deadlineAtMs`：绝对截止时间
  - `remainingMs()`：子操作的剩余预算
- 在以下位置使用此辅助函数：
  - `src/browser/client-fetch.ts`（HTTP 和进程内调度）
  - `src/node-host/runner.ts`（代理路径）
  - 浏览器操作实现（Playwright 和 CDP）

### 2. 独立 Evaluate 引擎（CDP 路径）

添加基于 CDP 的 evaluate 实现，不与 Playwright 的页面命令队列共享。关键属性是 evaluate 传输使用独立的 WebSocket 连接和附加到目标的独立 CDP 会话。

实现方向：

- 新模块，例如 `src/browser/cdp-evaluate.ts`，功能包括：
  - 连接到配置的 CDP 端点（浏览器级 socket）。
  - 使用 `Target.attachToTarget({ targetId, flatten: true })` 获取 `sessionId`。
  - 执行以下操作之一：
    - `Runtime.evaluate` 用于页面级 evaluate，或
    - `DOM.resolveNode` 加 `Runtime.callFunctionOn` 用于元素级 evaluate。
  - 超时或中止时：
    - 尽力发送 `Runtime.terminateExecution`。
    - 关闭 WebSocket 并返回明确的错误。

说明：

- 这仍然在页面中执行 JavaScript，因此终止可能有副作用。好处在于它不会阻塞 Playwright 队列，并且可以通过关闭 CDP 会话在传输层取消。

### 3. 引用方案（无需完全重写的元素定位）

难点在于元素定位。CDP 需要 DOM 句柄或 `backendDOMNodeId`，而目前大多数浏览器操作使用基于快照引用的 Playwright 定位器。

推荐方案：保留现有引用，但附加可选的 CDP 可解析 ID。

#### 3.1 扩展存储的引用信息

扩展存储的角色引用元数据以可选地包含 CDP ID：

- 当前：`{ role, name, nth }`
- 提案：`{ role, name, nth, backendDOMNodeId?: number }`

这使所有现有基于 Playwright 的操作继续工作，并允许 CDP evaluate 在 `backendDOMNodeId` 可用时接受相同的 `ref` 值。

#### 3.2 在快照时填充 backendDOMNodeId

生成角色快照时：

1. 像今天一样生成现有的角色引用映射（role、name、nth）。
2. 通过 CDP 获取 AX 树（`Accessibility.getFullAXTree`），使用相同的重复处理规则计算 `(role, name, nth) -> backendDOMNodeId` 的并行映射。
3. 将 ID 合并回当前标签页的存储引用信息中。

如果某个引用映射失败，保持 `backendDOMNodeId` 为 undefined。这使该功能成为尽力而为且可安全上线的。

#### 3.3 带引用的 Evaluate 行为

在 `act:evaluate` 中：

- 如果 `ref` 存在且有 `backendDOMNodeId`，通过 CDP 运行元素 evaluate。
- 如果 `ref` 存在但没有 `backendDOMNodeId`，回退到 Playwright 路径（仍然有界且可中止）。

可选的逃生通道：

- 扩展请求形状以接受 `backendDOMNodeId` 直接用于高级调用方（以及调试），同时保持 `ref` 作为主要接口。

### 4. 保留最后手段恢复路径

即使有 CDP evaluate，仍有其他方式可能阻塞标签页或连接。保留现有恢复机制（terminate execution + 断开 Playwright 连接）作为最后手段，用于：

- 旧版调用方
- CDP attach 被阻止的环境
- 意外的 Playwright 边缘情况

## 实现计划（单次迭代）

### 交付物

- 基于 CDP 的 evaluate 引擎，运行在 Playwright 页面命令队列之外。
- 调用方和处理器一致使用的单一端到端超时/中止预算。
- 可选地携带 `backendDOMNodeId` 的引用元数据，用于元素 evaluate。
- `act:evaluate` 在可能时优先使用 CDP 引擎，否则回退到 Playwright。
- 证明卡住的 evaluate 不会阻塞后续操作的测试。
- 使故障和回退可见的日志/指标。

### 实现清单

1. 添加共享的"预算"辅助函数，将 `timeoutMs` + 上游 `AbortSignal` 链接为：
   - 单一 `AbortSignal`
   - 绝对截止时间
   - 用于下游操作的 `remainingMs()` 辅助函数
2. 更新所有调用路径以使用该辅助函数，使 `timeoutMs` 在所有位置含义一致：
   - `src/browser/client-fetch.ts`（HTTP 和进程内调度）
   - `src/node-host/runner.ts`（node 代理路径）
   - 调用 `/act` 的 CLI 封装器（为 `browser evaluate` 添加 `--timeout-ms`）
3. 实现 `src/browser/cdp-evaluate.ts`：
   - 连接到浏览器级 CDP socket
   - `Target.attachToTarget` 获取 `sessionId`
   - 运行 `Runtime.evaluate` 用于页面 evaluate
   - 运行 `DOM.resolveNode` + `Runtime.callFunctionOn` 用于元素 evaluate
   - 超时/中止时：尽力 `Runtime.terminateExecution` 然后关闭 socket
4. 扩展存储的角色引用元数据以可选地包含 `backendDOMNodeId`：
   - 保持现有的 `{ role, name, nth }` 行为用于 Playwright 操作
   - 添加 `backendDOMNodeId?: number` 用于 CDP 元素定位
5. 在快照创建期间填充 `backendDOMNodeId`（尽力而为）：
   - 通过 CDP 获取 AX 树（`Accessibility.getFullAXTree`）
   - 计算 `(role, name, nth) -> backendDOMNodeId` 并合并到存储的引用映射中
   - 如果映射不明确或缺失，保持 ID 为 undefined
6. 更新 `act:evaluate` 路由：
   - 如果没有 `ref`：始终使用 CDP evaluate
   - 如果 `ref` 解析到 `backendDOMNodeId`：使用 CDP 元素 evaluate
   - 否则：回退到 Playwright evaluate（仍然有界且可中止）
7. 保留现有的"最后手段"恢复路径作为回退，而非默认路径。
8. 添加测试：
   - 卡住的 evaluate 在预算内超时，下一次 click/type 成功
   - 中止取消 evaluate（客户端断开或超时）并解除后续操作的阻塞
   - 映射失败时干净地回退到 Playwright
9. 添加可观测性：
   - evaluate 持续时间和超时计数器
   - terminateExecution 使用情况
   - 回退率（CDP -> Playwright）和原因

### 验收标准

- 故意挂起的 `act:evaluate` 在调用方预算内返回，不会阻塞该标签页的后续操作。
- `timeoutMs` 在 CLI、代理工具、node 代理和进程内调用中行为一致。
- 如果 `ref` 可以映射到 `backendDOMNodeId`，元素 evaluate 使用 CDP；否则回退路径仍然有界且可恢复。

## 测试计划

- 单元测试：
  - `(role, name, nth)` 在角色引用和 AX 树节点之间的匹配逻辑。
  - 预算辅助函数行为（余量、剩余时间计算）。
- 集成测试：
  - CDP evaluate 超时在预算内返回且不阻塞下一个操作。
  - 中止取消 evaluate 并尽力触发终止。
- 契约测试：
  - 确保 `BrowserActRequest` 和 `BrowserActResponse` 保持兼容。

## 风险和缓解措施

- 映射不完美：
  - 缓解：尽力映射，回退到 Playwright evaluate，并添加调试工具。
- `Runtime.terminateExecution` 有副作用：
  - 缓解：仅在超时/中止时使用，并在错误中记录该行为。
- 额外开销：
  - 缓解：仅在请求快照时获取 AX 树，按目标缓存，保持 CDP 会话短生命周期。
- 扩展中继限制：
  - 缓解：当每页 socket 不可用时使用浏览器级 attach API，并保留当前 Playwright 路径作为回退。

## 开放问题

- 新引擎是否应该可配置为 `playwright`、`cdp` 或 `auto`？
- 是否要为高级用户暴露新的 "nodeRef" 格式，还是仅保留 `ref`？
- frame 快照和选择器范围快照应如何参与 AX 映射？
