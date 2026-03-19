---
title: 插件智能体工具
---
OpenClaw 插件可以注册**智能体工具**（JSON 模式函数），这些工具在智能体运行期间暴露给 LLM。工具可以是**必需的**（始终可用）或**可选的**（选择启用）。

智能体工具在主配置的 `tools` 下配置，或在每个智能体的 `agents.list[].tools` 下配置。允许列表/拒绝列表策略控制智能体可以调用哪些工具。

## 基本工具

```ts
import { Type } from "@sinclair/typebox";

export default function (api) {
  api.registerTool({
    name: "my_tool",
    description: "Do a thing",
    parameters: Type.Object({
      input: Type.String(),
    }),
    async execute(_id, params) {
      return { content: [{ type: "text", text: params.input }] };
    },
  });
}
```

## 可选工具（选择启用）

可选工具**永远不会**自动启用。用户必须将它们添加到智能体允许列表中。

```ts
export default function (api) {
  api.registerTool(
    {
      name: "workflow_tool",
      description: "Run a local workflow",
      parameters: {
        type: "object",
        properties: {
          pipeline: { type: "string" },
        },
        required: ["pipeline"],
      },
      async execute(_id, params) {
        return { content: [{ type: "text", text: params.pipeline }] };
      },
    },
    { optional: true },
  );
}
```

在 `agents.list[].tools.allow`（或全局 `tools.allow`）中启用可选工具：

```json5
{
  agents: {
    list: [
      {
        id: "main",
        tools: {
          allow: [
            "workflow_tool", // 特定工具名称
            "workflow", // 插件 id（启用该插件的所有工具）
            "group:plugins", // 所有插件工具
          ],
        },
      },
    ],
  },
}
```

其他影响工具可用性的配置选项：

- 仅包含插件工具名称的允许列表被视为插件选择启用；核心工具保持启用，除非你在允许列表中也包含核心工具或组。
- `tools.profile` / `agents.list[].tools.profile`（基础允许列表）
- `tools.byProvider` / `agents.list[].tools.byProvider`（特定提供商的允许/拒绝）
- `tools.sandbox.tools.*`（沙箱隔离时的沙箱工具策略）

## 规则 + 提示

- 工具名称**不能**与核心工具名称冲突；冲突的工具会被跳过。
- 允许列表中使用的插件 id 不能与核心工具名称冲突。
- 对于触发副作用或需要额外二进制文件/凭证的工具，优先使用 `optional: true`。
