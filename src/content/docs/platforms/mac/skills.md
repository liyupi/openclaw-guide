---
title: Skills
---
macOS 应用通过 Gateway 网关展示 OpenClaw Skills；它不会在本地解析 Skills。

## 数据来源

- `skills.status`（Gateway 网关）返回所有 Skills 以及资格和缺失的要求
  （包括内置 Skills 的允许列表阻止情况）。
- 要求来源于每个 `SKILL.md` 中的 `metadata.openclaw.requires`。

## 安装操作

- `metadata.openclaw.install` 定义安装选项（brew/node/go/uv）。
- 应用调用 `skills.install` 在 Gateway 网关主机上运行安装器。
- 当提供多个安装器时，Gateway 网关仅展示一个首选安装器
  （如果可用则使用 brew，否则使用来自 `skills.install` 的 node 管理器，默认 npm）。

## 环境变量/API 密钥

- 应用将密钥存储在 `~/.openclaw/openclaw.json` 的 `skills.entries.<skillKey>` 下。
- `skills.update` 更新 `enabled`、`apiKey` 和 `env`。

## 远程模式

- 安装 + 配置更新发生在 Gateway 网关主机上（不是本地 Mac）。
