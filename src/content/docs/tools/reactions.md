---
title: 表情回应
---
跨渠道共享的表情回应语义：

- 添加表情回应时，`emoji` 为必填项。
- `emoji=""` 在支持的情况下移除机器人的表情回应。
- `remove: true` 在支持的情况下移除指定的表情（需要提供 `emoji`）。

渠道说明：

- **Discord/Slack**：空 `emoji` 移除机器人在该消息上的所有表情回应；`remove: true` 仅移除指定的表情。
- **Google Chat**：空 `emoji` 移除应用在该消息上的表情回应；`remove: true` 仅移除指定的表情。
- **Telegram**：空 `emoji` 移除机器人的表情回应；`remove: true` 同样移除表情回应，但工具验证仍要求 `emoji` 为非空值。
- **WhatsApp**：空 `emoji` 移除机器人的表情回应；`remove: true` 映射为空 emoji（仍需提供 `emoji`）。
- **Signal**：当启用 `channels.signal.reactionNotifications` 时，收到的表情回应通知会触发系统事件。
