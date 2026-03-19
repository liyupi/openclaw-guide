---
title: apply_patch 工具
---
使用结构化补丁格式应用文件更改。这非常适合多文件
或多段编辑，在这些场景下单次 `edit` 调用会很脆弱。

该工具接受一个 `input` 字符串，其中包含一个或多个文件操作：

```
*** Begin Patch
*** Add File: path/to/file.txt
+line 1
+line 2
*** Update File: src/app.ts
@@
-old line
+new line
*** Delete File: obsolete.txt
*** End Patch
```

## 参数

- `input`（必需）：完整的补丁内容，包括 `*** Begin Patch` 和 `*** End Patch`。

## 说明

- 路径相对于工作区根目录解析。
- 在 `*** Update File:` 段中使用 `*** Move to:` 可重命名文件。
- 需要时使用 `*** End of File` 标记仅在文件末尾的插入。
- 实验性功能，默认禁用。通过 `tools.exec.applyPatch.enabled` 启用。
- 仅限 OpenAI（包括 OpenAI Codex）。可选通过
  `tools.exec.applyPatch.allowModels` 按模型进行限制。
- 配置仅在 `tools.exec` 下。

## 示例

```json
{
  "tool": "apply_patch",
  "input": "*** Begin Patch\n*** Update File: src/index.ts\n@@\n-const foo = 1\n+const foo = 2\n*** End Patch"
}
```
