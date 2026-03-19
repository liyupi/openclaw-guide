---
title: system
---
Gateway 网关的系统级辅助工具：入队系统事件、控制心跳和查看在线状态。

## 常用命令

```bash
openclaw system event --text "Check for urgent follow-ups" --mode now
openclaw system heartbeat enable
openclaw system heartbeat last
openclaw system presence
```

## `system event`

在**主**会话上入队系统事件。下一次心跳会将其作为 `System:` 行注入到提示中。使用 `--mode now` 立即触发心跳；`next-heartbeat` 等待下一个计划的心跳时刻。

标志：

- `--text <text>`：必填的系统事件文本。
- `--mode <mode>`：`now` 或 `next-heartbeat`（默认）。
- `--json`：机器可读输出。

## `system heartbeat last|enable|disable`

心跳控制：

- `last`：显示最后一次心跳事件。
- `enable`：重新开启心跳（如果之前被禁用，使用此命令）。
- `disable`：暂停心跳。

标志：

- `--json`：机器可读输出。

## `system presence`

列出 Gateway 网关已知的当前系统在线状态条目（节点、实例和类似状态行）。

标志：

- `--json`：机器可读输出。

## 注意

- 需要一个运行中的 Gateway 网关，可通过你当前的配置访问（本地或远程）。
- 系统事件是临时的，不会在重启后持久化。
