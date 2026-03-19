---
title: Zalo Personal 插件
---
通过插件为 OpenClaw 提供 Zalo Personal 支持，使用 `zca-cli` 自动化普通 Zalo 用户账户。

> **警告：** 非官方自动化可能导致账户被暂停/封禁。使用风险自负。

## 命名

渠道 id 是 `zalouser`，以明确表示这是自动化**个人 Zalo 用户账户**（非官方）。我们保留 `zalo` 用于潜在的未来官方 Zalo API 集成。

## 运行位置

此插件**在 Gateway 网关进程内**运行。

如果你使用远程 Gateway 网关，请在**运行 Gateway 网关的机器**上安装/配置它，然后重启 Gateway 网关。

## 安装

### 选项 A：从 npm 安装

```bash
openclaw plugins install @openclaw/zalouser
```

之后重启 Gateway 网关。

### 选项 B：从本地文件夹安装（开发）

```bash
openclaw plugins install ./extensions/zalouser
cd ./extensions/zalouser && pnpm install
```

之后重启 Gateway 网关。

## 前置条件：zca-cli

Gateway 网关机器必须在 `PATH` 中有 `zca`：

```bash
zca --version
```

## 配置

渠道配置位于 `channels.zalouser` 下（不是 `plugins.entries.*`）：

```json5
{
  channels: {
    zalouser: {
      enabled: true,
      dmPolicy: "pairing",
    },
  },
}
```

## CLI

```bash
openclaw channels login --channel zalouser
openclaw channels logout --channel zalouser
openclaw channels status --probe
openclaw message send --channel zalouser --target <threadId> --message "Hello from OpenClaw"
openclaw directory peers list --channel zalouser --query "name"
```

## 智能体工具

工具名称：`zalouser`

操作：`send`、`image`、`link`、`friends`、`groups`、`me`、`status`
