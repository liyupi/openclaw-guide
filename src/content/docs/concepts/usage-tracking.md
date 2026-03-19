---
title: 使用量跟踪
---
## 功能简介

- 直接从提供商的使用量端点拉取使用量/配额数据。
- 不提供估算费用；仅展示提供商报告的时间窗口数据。

## 展示位置

- 聊天中的 `/status`：包含会话 token 数和估算费用的表情符号丰富的状态卡片（仅限 API 密钥）。当可用时，会显示**当前模型提供商**的使用量。
- 聊天中的 `/usage off|tokens|full`：每次响应的使用量页脚（OAuth 仅显示 token 数）。
- 聊天中的 `/usage cost`：从 OpenClaw 会话日志汇总的本地费用摘要。
- CLI：`openclaw status --usage` 打印完整的按提供商分类的详细信息。
- CLI：`openclaw channels list` 在提供商配置旁打印相同的使用量快照（使用 `--no-usage` 跳过）。
- macOS 菜单栏：上下文菜单下的"使用量"部分（仅在可用时显示）。

## 提供商及凭据

- **Anthropic (Claude)**：认证配置中的 OAuth 令牌。
- **GitHub Copilot**：认证配置中的 OAuth 令牌。
- **Gemini CLI**：认证配置中的 OAuth 令牌。
- **Antigravity**：认证配置中的 OAuth 令牌。
- **OpenAI Codex**：认证配置中的 OAuth 令牌（存在时使用 accountId）。
- **MiniMax**：API 密钥（编程计划密钥；`MINIMAX_CODE_PLAN_KEY` 或 `MINIMAX_API_KEY`）；使用 5 小时编程计划时间窗口。
- **z.ai**：通过环境变量/配置/认证存储提供的 API 密钥。

如果没有匹配的 OAuth/API 凭据，使用量信息将被隐藏。
