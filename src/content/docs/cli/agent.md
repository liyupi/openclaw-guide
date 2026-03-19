---
title: agent
---
通过 Gateway 网关运行智能体回合（使用 `--local` 进行嵌入式运行）。使用 `--agent <id>` 直接指定已配置的智能体。

相关内容：

- 智能体发送工具：[Agent send](/tools/agent-send)

## 示例

```bash
openclaw agent --to +15555550123 --message "status update" --deliver
openclaw agent --agent ops --message "Summarize logs"
openclaw agent --session-id 1234 --message "Summarize inbox" --thinking medium
openclaw agent --agent ops --message "Generate report" --deliver --reply-channel slack --reply-to "#reports"
```
