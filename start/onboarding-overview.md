---
summary: "OpenClaw 引导流程选项和流程概览"
read_when:
  - 选择引导路径
  - 设置新环境
title: "Onboarding Overview"
sidebarTitle: "引导概览"
---

# 引导概览

OpenClaw 支持多种引导路径，具体取决于 Gateway 运行的位置以及你偏好的提供者配置方式。

## 选择你的引导路径

- **CLI 向导**适用于 macOS、Linux 和 Windows（通过 WSL2）。
- **macOS 应用**适用于在 Apple silicon 或 Intel Mac 上进行引导式首次运行。

## CLI 引导向导

在终端中运行向导：

```bash
openclaw onboard
```

当你需要完全控制 Gateway、工作区、频道和 Skills 时，使用 CLI 向导。文档：

- [引导向导（CLI）](/start/wizard)
- [`openclaw onboard` 命令](/cli/onboard)

## macOS 应用引导

当你需要在 macOS 上进行完全引导式设置时，使用 OpenClaw 应用。文档：

- [引导（macOS 应用）](/start/onboarding)

## 自定义提供者

如果你需要一个未列出的端点，包括暴露标准 OpenAI 或 Anthropic API 的托管提供者，请在 CLI 向导中选择 **Custom Provider**。你需要：

- 选择 OpenAI 兼容、Anthropic 兼容或 **Unknown**（自动检测）。
- 输入 base URL 和 API key（如果提供者需要）。
- 提供模型 ID 和可选别名。
- 选择 Endpoint ID，以便多个自定义端点可以共存。

详细步骤请参考上面的 CLI 引导文档。
