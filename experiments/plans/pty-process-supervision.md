---
summary: "可靠交互式进程监督（PTY + 非 PTY）的生产计划，具有显式所有权、统一生命周期和确定性清理"
read_when:
  - 处理 exec/进程生命周期所有权和清理时
  - 调试 PTY 和非 PTY 监督行为时
owner: "openclaw"
status: "in-progress"
last_updated: "2026-02-15"
title: "PTY and Process Supervision Plan"
---

# PTY 和进程监督计划

## 1. 问题和目标

我们需要为长时间运行的命令执行提供一个可靠的生命周期，覆盖：

- `exec` 前台运行
- `exec` 后台运行
- `process` 后续操作（`poll`、`log`、`send-keys`、`paste`、`submit`、`kill`、`remove`）
- CLI 代理运行器子进程

目标不仅仅是支持 PTY。目标是可预测的所有权、取消、超时和清理，没有不安全的进程匹配启发式。

## 2. 范围和边界

- 保持实现在 `src/process/supervisor` 内部。
- 不为此创建新包。
- 在实际可行的情况下保持当前行为兼容性。
- 不将范围扩大到终端重放或 tmux 风格的会话持久化。

## 3. 本分支中的实现

### 监督器基线已就位

- 监督器模块位于 `src/process/supervisor/*` 下。
- Exec 运行时和 CLI 运行器已通过监督器 spawn 和 wait 路由。
- 注册表最终化是幂等的。

### 本轮完成内容

1. 显式 PTY 命令契约

- `SpawnInput` 现在是 `src/process/supervisor/types.ts` 中的可辨识联合类型。
- PTY 运行要求使用 `ptyCommand` 而非复用通用 `argv`。
- 监督器不再在 `src/process/supervisor/supervisor.ts` 中通过 argv 拼接重建 PTY 命令字符串。
- Exec 运行时现在在 `src/agents/bash-tools.exec-runtime.ts` 中直接传递 `ptyCommand`。

2. 进程层类型解耦

- 监督器类型不再从 agents 导入 `SessionStdin`。
- 进程本地 stdin 契约位于 `src/process/supervisor/types.ts`（`ManagedRunStdin`）中。
- 适配器现在仅依赖进程层类型：
  - `src/process/supervisor/adapters/child.ts`
  - `src/process/supervisor/adapters/pty.ts`

3. 进程工具生命周期所有权改进

- `src/agents/bash-tools.process.ts` 现在首先通过监督器请求取消。
- `process kill/remove` 现在在监督器查找未命中时使用进程树回退终止。
- `remove` 通过在请求终止后立即删除运行中的会话条目来保持确定性移除行为。

4. 单一来源看门狗默认值

- 在 `src/agents/cli-watchdog-defaults.ts` 中添加了共享默认值。
- `src/agents/cli-backends.ts` 消费共享默认值。
- `src/agents/cli-runner/reliability.ts` 消费相同的共享默认值。

5. 死代码辅助函数清理

- 从 `src/agents/bash-tools.shared.ts` 中移除了未使用的 `killSession` 辅助路径。

6. 添加了直接监督器路径测试

- 添加了 `src/agents/bash-tools.process.supervisor.test.ts` 以覆盖通过监督器取消的 kill 和 remove 路由。

7. 可靠性缺口修复已完成

- `src/agents/bash-tools.process.ts` 现在在监督器查找未命中时回退到真实的操作系统级进程终止。
- `src/process/supervisor/adapters/child.ts` 现在对默认的 cancel/超时 kill 路径使用进程树终止语义。
- 在 `src/process/kill-tree.ts` 中添加了共享的进程树工具。

8. 添加了 PTY 契约边缘情况覆盖

- 添加了 `src/process/supervisor/supervisor.pty-command.test.ts` 用于逐字 PTY 命令转发和空命令拒绝。
- 添加了 `src/process/supervisor/adapters/child.test.ts` 用于子适配器取消中的进程树 kill 行为。

## 4. 剩余缺口和决策

### 可靠性状态

本轮所需的两个可靠性缺口现已关闭：

- `process kill/remove` 现在在监督器查找未命中时有真实的操作系统终止回退。
- 子进程 cancel/超时现在对默认 kill 路径使用进程树 kill 语义。
- 已为这两种行为添加了回归测试。

### 持久性和启动协调

重启行为现在被显式定义为仅内存生命周期。

- `reconcileOrphans()` 在 `src/process/supervisor/supervisor.ts` 中设计上保持为空操作。
- 活跃运行在进程重启后不恢复。
- 此边界对于本次实现轮是有意的，以避免部分持久化的风险。

### 可维护性后续

1. `src/agents/bash-tools.exec-runtime.ts` 中的 `runExecProcess` 仍然处理多个职责，可在后续中拆分为专注的辅助函数。

## 5. 实现计划

所需可靠性和契约项目的实现轮次已完成。

已完成：

- `process kill/remove` 回退真实终止
- 子适配器默认 kill 路径的进程树取消
- 回退 kill 和子适配器 kill 路径的回归测试
- 显式 `ptyCommand` 下的 PTY 命令边缘情况测试
- 显式的仅内存重启边界，`reconcileOrphans()` 设计上为空操作

可选后续：

- 将 `runExecProcess` 拆分为专注的辅助函数且不改变行为

## 6. 文件映射

### 进程监督器

- `src/process/supervisor/types.ts` 已更新为可辨识 spawn 输入和进程本地 stdin 契约。
- `src/process/supervisor/supervisor.ts` 已更新为使用显式 `ptyCommand`。
- `src/process/supervisor/adapters/child.ts` 和 `src/process/supervisor/adapters/pty.ts` 已与代理类型解耦。
- `src/process/supervisor/registry.ts` 幂等最终化未更改并保留。

### Exec 和进程集成

- `src/agents/bash-tools.exec-runtime.ts` 已更新为显式传递 PTY 命令并保留回退路径。
- `src/agents/bash-tools.process.ts` 已更新为通过监督器取消并带真实进程树回退终止。
- `src/agents/bash-tools.shared.ts` 已移除直接 kill 辅助路径。

### CLI 可靠性

- `src/agents/cli-watchdog-defaults.ts` 已添加为共享基线。
- `src/agents/cli-backends.ts` 和 `src/agents/cli-runner/reliability.ts` 现在消费相同的默认值。

## 7. 本轮验证运行

单元测试：

- `pnpm vitest src/process/supervisor/registry.test.ts`
- `pnpm vitest src/process/supervisor/supervisor.test.ts`
- `pnpm vitest src/process/supervisor/supervisor.pty-command.test.ts`
- `pnpm vitest src/process/supervisor/adapters/child.test.ts`
- `pnpm vitest src/agents/cli-backends.test.ts`
- `pnpm vitest src/agents/bash-tools.exec.pty-cleanup.test.ts`
- `pnpm vitest src/agents/bash-tools.process.poll-timeout.test.ts`
- `pnpm vitest src/agents/bash-tools.process.supervisor.test.ts`
- `pnpm vitest src/process/exec.test.ts`

端到端目标：

- `pnpm vitest src/agents/cli-runner.test.ts`
- `pnpm vitest run src/agents/bash-tools.exec.pty-fallback.test.ts src/agents/bash-tools.exec.background-abort.test.ts src/agents/bash-tools.process.send-keys.test.ts`

类型检查说明：

- 在此仓库中使用 `pnpm build`（以及 `pnpm check` 用于完整的 lint/文档门控）。提到 `pnpm tsgo` 的旧笔记已过时。

## 8. 保留的运营保证

- Exec 环境加固行为未更改。
- 审批和允许列表流程未更改。
- 输出净化和输出上限未更改。
- PTY 适配器仍然保证在强制 kill 和监听器释放时的 wait 结算。

## 9. 完成定义

1. 监督器是托管运行的生命周期所有者。
2. PTY spawn 使用显式命令契约，无 argv 重建。
3. 进程层在监督器 stdin 契约方面不依赖代理层类型。
4. 看门狗默认值为单一来源。
5. 定向的单元和端到端测试保持绿色。
6. 重启持久性边界被显式记录或完全实现。

## 10. 总结

此分支现在具有一致且更安全的监督形状：

- 显式 PTY 契约
- 更清晰的进程分层
- 监督器驱动的进程操作取消路径
- 监督器查找未命中时的真实回退终止
- 子运行默认 kill 路径的进程树取消
- 统一的看门狗默认值
- 显式的仅内存重启边界（本轮不跨重启协调孤儿进程）
