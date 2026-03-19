---
title: 浏览器登录
---
## 手动登录（推荐）

当网站需要登录时，请在**主机**浏览器配置文件（openclaw 浏览器）中**手动登录**。

**不要**将你的凭证提供给模型。自动登录通常会触发反机器人防御并可能锁定账户。

返回主浏览器文档：[浏览器](/tools/browser)。

## 使用哪个 Chrome 配置文件？

OpenClaw 控制一个**专用的 Chrome 配置文件**（名为 `openclaw`，橙色调 UI）。这与你的日常浏览器配置文件是分开的。

两种简单的访问方式：

1. **让智能体打开浏览器**，然后你自己登录。
2. **通过 CLI 打开**：

```bash
openclaw browser start
openclaw browser open https://x.com
```

如果你有多个配置文件，传入 `--browser-profile <name>`（默认是 `openclaw`）。

## X/Twitter：推荐流程

- **阅读/搜索/话题：** 使用 **bird** CLI Skills（无浏览器，稳定）。
  - 仓库：https://github.com/steipete/bird
- **发布更新：** 使用**主机**浏览器（手动登录）。

## 沙箱隔离 + 主机浏览器访问

沙箱隔离的浏览器会话**更容易**触发机器人检测。对于 X/Twitter（和其他严格的网站），优先使用**主机**浏览器。

如果智能体在沙箱中，浏览器工具默认使用沙箱。要允许主机控制：

```json5
{
  agents: {
    defaults: {
      sandbox: {
        mode: "non-main",
        browser: {
          allowHostControl: true,
        },
      },
    },
  },
}
```

然后定位主机浏览器：

```bash
openclaw browser open https://x.com --browser-profile openclaw --target host
```

或者为发布更新的智能体禁用沙箱隔离。
