---
title: 新手引导和配置协议
---
目的：CLI、macOS 应用和 Web UI 之间共享的新手引导 + 配置界面。

## 组件

- 向导引擎（共享会话 + 提示 + 新手引导状态）。
- CLI 新手引导使用与 UI 客户端相同的向导流程。
- Gateway 网关 RPC 公开向导 + 配置模式端点。
- macOS 新手引导使用向导步骤模型。
- Web UI 从 JSON Schema + UI 提示渲染配置表单。

## Gateway 网关 RPC

- `wizard.start` 参数：`{ mode?: "local"|"remote", workspace?: string }`
- `wizard.next` 参数：`{ sessionId, answer?: { stepId, value? } }`
- `wizard.cancel` 参数：`{ sessionId }`
- `wizard.status` 参数：`{ sessionId }`
- `config.schema` 参数：`{}`

响应（结构）

- 向导：`{ sessionId, done, step?, status?, error? }`
- 配置模式：`{ schema, uiHints, version, generatedAt }`

## UI 提示

- `uiHints` 按路径键入；可选元数据（label/help/group/order/advanced/sensitive/placeholder）。
- 敏感字段渲染为密码输入；无脱敏层。
- 不支持的模式节点回退到原始 JSON 编辑器。

## 注意

- 本文档是跟踪新手引导/配置协议重构的唯一位置。
