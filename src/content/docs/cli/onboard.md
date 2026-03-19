---
title: onboard
---
交互式新手引导向导（本地或远程 Gateway 网关设置）。

相关内容：

- 向导指南：[新手引导](/start/onboarding)

## 示例

```bash
openclaw onboard
openclaw onboard --flow quickstart
openclaw onboard --flow manual
openclaw onboard --mode remote --remote-url ws://gateway-host:18789
```

流程说明：

- `quickstart`：最少提示，自动生成 Gateway 网关令牌。
- `manual`：完整的端口/绑定/认证提示（`advanced` 的别名）。
- 最快开始聊天：`openclaw dashboard`（控制 UI，无需渠道设置）。
