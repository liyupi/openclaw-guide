---
title: security
---
安全工具（审计 + 可选修复）。

相关：

- 安全指南：[安全](/gateway/security)

## 审计

```bash
openclaw security audit
openclaw security audit --deep
openclaw security audit --fix
```

当多个私信发送者共享主会话时，审计会发出警告，并建议对共享收件箱使用 `session.dmScope="per-channel-peer"`（或多账户渠道使用 `per-account-channel-peer`）。
当使用小模型（`<=300B`）且未启用沙箱隔离但启用了 web/browser 工具时，它也会发出警告。
