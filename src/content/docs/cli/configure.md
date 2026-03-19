---
title: configure
---
用于设置凭证、设备和智能体默认值的交互式提示。

注意：**模型**部分现在包含一个用于 `agents.defaults.models` 允许列表的多选项（显示在 `/model` 和模型选择器中的内容）。

提示：不带子命令的 `openclaw config` 会打开相同的向导。使用 `openclaw config get|set|unset` 进行非交互式编辑。

相关内容：

- Gateway 网关配置参考：[配置](/gateway/configuration)
- Config CLI：[Config](/cli/config)

注意事项：

- 选择 Gateway 网关运行位置始终会更新 `gateway.mode`。如果这是你唯一需要的，可以不选择其他部分直接选择"继续"。
- 面向渠道的服务（Slack/Discord/Matrix/Microsoft Teams）在设置期间会提示输入频道/房间允许列表。你可以输入名称或 ID；向导会尽可能将名称解析为 ID。

## 示例

```bash
openclaw configure
openclaw configure --section models --section channels
```
