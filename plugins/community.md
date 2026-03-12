---
summary: "社区插件：质量标准、托管要求和 PR 提交流程"
read_when:
  - 你想发布第三方 OpenClaw 插件
  - 你想提交插件以在文档中列出
title: "Community plugins"
---

# 社区插件

本页面收录高质量的 **社区维护插件**。

我们接受符合质量标准的社区插件 PR。

## 列入要求

- 插件包已发布在 npmjs 上（可通过 `openclaw plugins install <npm-spec>` 安装）。
- 源代码托管在 GitHub 上（公开仓库）。
- 仓库包含设置/使用文档和 Issue 跟踪器。
- 插件有明确的维护信号（活跃的维护者、最近的更新或及时的 Issue 处理）。

## 如何提交

提交 PR 将你的插件添加到本页面，需包含：

- 插件名称
- npm 包名
- GitHub 仓库 URL
- 一行描述
- 安装命令

## 审核标准

我们倾向于接受实用、文档完善且安全可靠的插件。低质量的封装、权属不明或无人维护的包可能会被拒绝。

## 候选格式

添加条目时请使用以下格式：

- **Plugin Name** — 简短描述
  npm: `@scope/package`
  repo: `https://github.com/org/repo`
  install: `openclaw plugins install @scope/package`

## 已列入的插件

- **WeChat** — 通过 WeChatPadPro（iPad 协议）将 OpenClaw 连接到微信个人账号。支持文本、图片和文件交换，可通过关键词触发对话。
  npm: `@icesword760/openclaw-wechat`
  repo: `https://github.com/icesword0760/openclaw-wechat`
  install: `openclaw plugins install @icesword760/openclaw-wechat`
