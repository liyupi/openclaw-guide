---
title: "Diffs"
summary: "用于代理的只读差异查看器和文件渲染器（可选插件工具）"
description: "使用可选的 Diffs 插件将前后文本或统一补丁渲染为网关托管的差异视图、文件（PNG 或 PDF）或两者兼有。"
read_when:
  - 你想让代理以差异形式显示代码或 Markdown 编辑
  - 你想要一个画布就绪的查看器 URL 或渲染的差异文件
  - 你需要具有安全默认值的受控临时差异制品
---

# Diffs

`diffs` 是一个可选的插件工具，具有简短的内置系统引导和伴随技能，可将变更内容转换为代理的只读差异制品。

它接受以下任一输入：

- `before` 和 `after` 文本
- 统一 `patch`

它可以返回：

- 用于画布展示的网关查看器 URL
- 用于消息传递的渲染文件路径（PNG 或 PDF）
- 一次调用中同时返回两种输出

启用后，插件会在系统提示空间中预置简洁的使用引导，并暴露详细的技能供代理在需要更完整指导时使用。

## 快速开始

1. 启用插件。
2. 使用 `mode: "view"` 调用 `diffs` 以实现画布优先的工作流。
3. 使用 `mode: "file"` 调用 `diffs` 以实现聊天文件传递工作流。
4. 使用 `mode: "both"` 调用 `diffs` 以同时获取两种制品。

## 启用插件

```json5
{
  plugins: {
    entries: {
      diffs: {
        enabled: true,
      },
    },
  },
}
```

## 禁用内置系统引导

如果你想保持 `diffs` 工具启用但禁用其内置系统提示引导，将 `plugins.entries.diffs.hooks.allowPromptInjection` 设为 `false`：

```json5
{
  plugins: {
    entries: {
      diffs: {
        enabled: true,
        hooks: {
          allowPromptInjection: false,
        },
      },
    },
  },
}
```

这会阻止 diffs 插件的 `before_prompt_build` 钩子，同时保持插件、工具和伴随技能可用。

如果你想同时禁用引导和工具，请改为禁用插件。

## 典型代理工作流

1. 代理调用 `diffs`。
2. 代理读取 `details` 字段。
3. 代理执行以下操作之一：
   - 使用 `canvas present` 打开 `details.viewerUrl`
   - 使用 `message` 发送 `details.filePath`，通过 `path` 或 `filePath`
   - 两者都执行

## 输入示例

前后对比：

```json
{
  "before": "# Hello\n\nOne",
  "after": "# Hello\n\nTwo",
  "path": "docs/example.md",
  "mode": "view"
}
```

补丁：

```json
{
  "patch": "diff --git a/src/example.ts b/src/example.ts\n--- a/src/example.ts\n+++ b/src/example.ts\n@@ -1 +1 @@\n-const x = 1;\n+const x = 2;\n",
  "mode": "both"
}
```

## 工具输入参考

除非注明，所有字段均为可选：

- `before`（`string`）：原始文本。当省略 `patch` 时需与 `after` 一起提供。
- `after`（`string`）：更新后的文本。当省略 `patch` 时需与 `before` 一起提供。
- `patch`（`string`）：统一差异文本。与 `before` 和 `after` 互斥。
- `path`（`string`）：前后对比模式的显示文件名。
- `lang`（`string`）：前后对比模式的语言覆盖提示。
- `title`（`string`）：查看器标题覆盖。
- `mode`（`"view" | "file" | "both"`）：输出模式。默认为插件默认值 `defaults.mode`。
- `theme`（`"light" | "dark"`）：查看器主题。默认为插件默认值 `defaults.theme`。
- `layout`（`"unified" | "split"`）：差异布局。默认为插件默认值 `defaults.layout`。
- `expandUnchanged`（`boolean`）：在完整上下文可用时展开未更改的部分。仅限单次调用选项（不是插件默认键）。
- `fileFormat`（`"png" | "pdf"`）：渲染文件格式。默认为插件默认值 `defaults.fileFormat`。
- `fileQuality`（`"standard" | "hq" | "print"`）：PNG 或 PDF 渲染的质量预设。
- `fileScale`（`number`）：设备缩放覆盖（`1`-`4`）。
- `fileMaxWidth`（`number`）：最大渲染宽度，以 CSS 像素为单位（`640`-`2400`）。
- `ttlSeconds`（`number`）：查看器制品 TTL，以秒为单位。默认 1800，最大 21600。
- `baseUrl`（`string`）：查看器 URL 来源覆盖。必须为 `http` 或 `https`，无查询/哈希。

验证和限制：

- `before` 和 `after` 各最大 512 KiB。
- `patch` 最大 2 MiB。
- `path` 最大 2048 字节。
- `lang` 最大 128 字节。
- `title` 最大 1024 字节。
- 补丁复杂度上限：最多 128 个文件和 120000 行总计。
- `patch` 和 `before` 或 `after` 一起使用会被拒绝。
- 渲染文件安全限制（适用于 PNG 和 PDF）：
  - `fileQuality: "standard"`：最大 8 MP（8,000,000 渲染像素）。
  - `fileQuality: "hq"`：最大 14 MP（14,000,000 渲染像素）。
  - `fileQuality: "print"`：最大 24 MP（24,000,000 渲染像素）。
  - PDF 还有最多 50 页的限制。

## 输出详情约定

工具在 `details` 下返回结构化元数据。

创建查看器的模式共享字段：

- `artifactId`
- `viewerUrl`
- `viewerPath`
- `title`
- `expiresAt`
- `inputKind`
- `fileCount`
- `mode`

渲染 PNG 或 PDF 时的文件字段：

- `filePath`
- `path`（与 `filePath` 相同的值，用于消息工具兼容性）
- `fileBytes`
- `fileFormat`
- `fileQuality`
- `fileScale`
- `fileMaxWidth`

模式行为总结：

- `mode: "view"`：仅查看器字段。
- `mode: "file"`：仅文件字段，无查看器制品。
- `mode: "both"`：查看器字段加文件字段。如果文件渲染失败，查看器仍返回并附带 `fileError`。

## 折叠的未更改部分

- 查看器可以显示类似 `N unmodified lines` 的行。
- 这些行上的展开控件是有条件的，不保证对每种输入类型都存在。
- 当渲染的差异具有可展开的上下文数据时，展开控件会出现，这在前后对比输入中很典型。
- 对于许多统一补丁输入，被省略的上下文正文在解析的补丁块中不可用，因此该行可能没有展开控件。这是预期行为。
- `expandUnchanged` 仅在存在可展开上下文时适用。

## 插件默认值

在 `~/.openclaw/openclaw.json` 中设置插件级别的默认值：

```json5
{
  plugins: {
    entries: {
      diffs: {
        enabled: true,
        config: {
          defaults: {
            fontFamily: "Fira Code",
            fontSize: 15,
            lineSpacing: 1.6,
            layout: "unified",
            showLineNumbers: true,
            diffIndicators: "bars",
            wordWrap: true,
            background: true,
            theme: "dark",
            fileFormat: "png",
            fileQuality: "standard",
            fileScale: 2,
            fileMaxWidth: 960,
            mode: "both",
          },
        },
      },
    },
  },
}
```

支持的默认值：

- `fontFamily`
- `fontSize`
- `lineSpacing`
- `layout`
- `showLineNumbers`
- `diffIndicators`
- `wordWrap`
- `background`
- `theme`
- `fileFormat`
- `fileQuality`
- `fileScale`
- `fileMaxWidth`
- `mode`

显式工具参数会覆盖这些默认值。

## 安全配置

- `security.allowRemoteViewer`（`boolean`，默认 `false`）
  - `false`：非回环请求到查看器路由被拒绝。
  - `true`：如果令牌化路径有效，允许远程查看器。

示例：

```json5
{
  plugins: {
    entries: {
      diffs: {
        enabled: true,
        config: {
          security: {
            allowRemoteViewer: false,
          },
        },
      },
    },
  },
}
```

## 制品生命周期和存储

- 制品存储在临时子文件夹下：`$TMPDIR/openclaw-diffs`。
- 查看器制品元数据包含：
  - 随机制品 ID（20 个十六进制字符）
  - 随机令牌（48 个十六进制字符）
  - `createdAt` 和 `expiresAt`
  - 存储的 `viewer.html` 路径
- 未指定时，默认查看器 TTL 为 30 分钟。
- 接受的最大查看器 TTL 为 6 小时。
- 清理在制品创建后机会性运行。
- 过期制品会被删除。
- 当缺少元数据时，回退清理会移除超过 24 小时的过期文件夹。

## 查看器 URL 和网络行为

查看器路由：

- `/plugins/diffs/view/{artifactId}/{token}`

查看器资源：

- `/plugins/diffs/assets/viewer.js`
- `/plugins/diffs/assets/viewer-runtime.js`

URL 构建行为：

- 如果提供了 `baseUrl`，在严格验证后使用它。
- 没有 `baseUrl` 时，查看器 URL 默认为回环 `127.0.0.1`。
- 如果网关绑定模式为 `custom` 且设置了 `gateway.customBindHost`，则使用该主机。

`baseUrl` 规则：

- 必须为 `http://` 或 `https://`。
- 查询和哈希会被拒绝。
- 允许来源加可选基础路径。

## 安全模型

查看器加固：

- 默认仅回环。
- 带有严格 ID 和令牌验证的令牌化查看器路径。
- 查看器响应 CSP：
  - `default-src 'none'`
  - 脚本和资源仅来自 self
  - 无出站 `connect-src`
- 启用远程访问时的远程未命中限流：
  - 每 60 秒 40 次失败
  - 60 秒锁定（`429 Too Many Requests`）

文件渲染加固：

- 截图浏览器请求路由默认拒绝。
- 仅允许来自 `http://127.0.0.1/plugins/diffs/assets/*` 的本地查看器资源。
- 外部网络请求被阻止。

## 文件模式的浏览器要求

`mode: "file"` 和 `mode: "both"` 需要 Chromium 兼容浏览器。

解析顺序：

1. OpenClaw 配置中的 `browser.executablePath`。
2. 环境变量：
   - `OPENCLAW_BROWSER_EXECUTABLE_PATH`
   - `BROWSER_EXECUTABLE_PATH`
   - `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH`
3. 平台命令/路径发现回退。

常见故障文本：

- `Diff PNG/PDF rendering requires a Chromium-compatible browser...`

通过安装 Chrome、Chromium、Edge 或 Brave，或设置上述可执行路径选项之一来修复。

## 故障排查

输入验证错误：

- `Provide patch or both before and after text.`
  - 同时提供 `before` 和 `after`，或提供 `patch`。
- `Provide either patch or before/after input, not both.`
  - 不要混合输入模式。
- `Invalid baseUrl: ...`
  - 使用带有可选路径的 `http(s)` 来源，无查询/哈希。
- `{field} exceeds maximum size (...)`
  - 减小负载大小。
- 大型补丁被拒绝
  - 减少补丁文件数量或总行数。

查看器可访问性问题：

- 查看器 URL 默认解析为 `127.0.0.1`。
- 对于远程访问场景，可以：
  - 每次工具调用传递 `baseUrl`，或
  - 使用 `gateway.bind=custom` 和 `gateway.customBindHost`
- 仅在你打算允许外部查看器访问时才启用 `security.allowRemoteViewer`。

未修改行没有展开按钮：

- 当补丁不包含可展开上下文时，补丁输入可能会出现这种情况。
- 这是预期行为，不表示查看器故障。

找不到制品：

- 制品因 TTL 过期。
- 令牌或路径已更改。
- 清理移除了过期数据。

## 操作指南

- 在画布中进行本地交互式审查时优先使用 `mode: "view"`。
- 对需要附件的出站聊天频道优先使用 `mode: "file"`。
- 除非你的部署需要远程查看器 URL，否则保持 `allowRemoteViewer` 禁用。
- 对敏感差异设置较短的显式 `ttlSeconds`。
- 非必要时避免在差异输入中发送敏感信息。
- 如果你的频道会积极压缩图片（例如 Telegram 或 WhatsApp），优先使用 PDF 输出（`fileFormat: "pdf"`）。

差异渲染引擎：

- 由 [Diffs](https://diffs.com) 提供支持。

## 相关文档

- [工具概览](/tools)
- [插件](/tools/plugin)
- [浏览器](/tools/browser)
