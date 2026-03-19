<p align="center">
  <img src="public/assets/openclaw-hero.svg" alt="OpenClaw" width="120" />
</p>

<h1 align="center">OpenClaw 中文网</h1>

<p align="center">
  <strong>OpenClaw 开源 AI 智能体的中文文档与介绍站，帮助中文用户快速上手并深入使用 OpenClaw。</strong>
</p>

<p align="center">
  <a href="https://www.clawfather.cn/">在线访问</a> ·
  <a href="https://github.com/openclaw/openclaw">OpenClaw 主仓库</a>
</p>
![image-20260319113321929](https://pic.yupi.icu/pine/image-20260319113321929.png)


---

## 简介

[OpenClaw](https://openclaw.ai) 是一个开源、可自托管的个人 AI 智能体（AI Agent），可通过 WhatsApp、Telegram、Discord、飞书、钉钉、企业微信等 20+ 聊天平台与你交互，帮你处理清理收件箱、发送邮件、管理日历等日常任务。运行在你自己的设备上，数据完全私有。

本仓库是 OpenClaw 的 **中文网站**，包含：

- **首页**（Landing Page）：产品介绍、快速安装等
- **文档站**：350+ 篇翻译文档，涵盖安装、渠道接入、模型配置、工具技能等全部内容

## 文档内容

| 板块 | 说明 |
|------|------|
| **快速开始** | 5 分钟从零到第一条消息，引导式安装向导 |
| **安装** | Docker、Podman、Nix、Ansible 等安装方式；Fly.io、Hetzner、GCP 等云端部署 |
| **消息渠道** | WhatsApp、Telegram、Discord、Slack、iMessage、飞书、钉钉、企业微信等 20+ 平台接入 |
| **代理** | Agent 架构、系统提示词、上下文管理、会话与记忆、多代理协作 |
| **工具与技能** | 内置工具、浏览器自动化、Skills 配置、Slash 命令、自动化（Cron/Webhook/Hook） |
| **模型** | OpenAI、Anthropic、Ollama、通义千问、Moonshot、GLM 等 30+ LLM 提供商配置 |
| **平台** | macOS、Windows、Linux、iOS、Android、Raspberry Pi 等平台适配 |
| **网关与运维** | Gateway 网关配置、安全与沙箱、OpenAI 兼容 API、Tailscale 远程访问 |
| **CLI 参考** | 40+ CLI 命令详细文档 |
| **速查表** | CLI 命令速查、Slash 命令速查 |

## 本地开发

### 前置要求

- [Node.js](https://nodejs.org) 18+
- npm

### 安装与启动

```bash
git clone https://github.com/liyupi/openclaw-guide.git
cd openclaw-guide
npm install
npm run dev
```

打开浏览器访问 `http://localhost:4321` 即可预览。

### 构建与预览

```bash
npm run build
npm run preview
```

## 技术栈

- **框架**：[Astro](https://astro.build) 6.x + [Starlight](https://starlight.astro.build) 0.38.x
- **语言**：TypeScript / MDX / Markdown
- **部署**：Cloudflare Pages（自定义域名 `docs.openclaw.ai`）
- **翻译工具链**：自研 i18n 翻译脚本 + 术语表 + 翻译记忆库

## 项目结构

```
openclaw-guide/
├── src/
│   ├── pages/index.astro         # 首页（Landing Page）
│   ├── content/docs/             # 文档内容（350+ Markdown/MDX）
│   │   ├── docs-home.mdx         # 文档概览页
│   │   ├── start/                # 快速开始
│   │   ├── install/              # 安装指南
│   │   ├── channels/             # 消息渠道
│   │   ├── concepts/             # 核心概念
│   │   ├── providers/            # 模型提供商
│   │   ├── platforms/            # 平台适配
│   │   ├── gateway/              # 网关配置
│   │   ├── cli/                  # CLI 命令参考
│   │   ├── cheatsheet/           # 速查表
│   │   └── ...
│   ├── components/               # 自定义组件（TabNav 等）
│   ├── overrides/Header.astro    # Starlight Header 覆写
│   ├── data/navigation.mjs       # 顶部 Tab 导航数据
│   └── styles/
│       ├── custom.css            # 文档页全局样式覆写
│       └── landing.css           # 首页样式
├── public/assets/                # 静态资源（Logo、图片等）
├── .i18n/                        # 术语表与翻译记忆库
├── scripts/                      # 工具脚本（迁移等）
├── astro.config.mjs              # Astro + Starlight 配置
└── package.json
```

## 交流

![c995612b-0b98-4677-bdb1-f11a29552cee](https://pic.yupi.icu/pine/c995612b-0b98-4677-bdb1-f11a29552cee.png)


## 参与贡献

欢迎提交 Issue 和 Pull Request 帮助改进中文文档！

- 发现翻译问题或错别字？请提交 [Issue](https://github.com/liyupi/openclaw-guide/issues)
- 想补充或修正文档内容？欢迎提交 PR
- 翻译风格请参考 `.i18n/glossary.zh-CN.json` 中的术语表

### 翻译规范

- CJK-Latin 间距遵循 W3C CLREQ（如 `Gateway 网关`、`Skills 配置`）
- 正文使用中文引号 `""`；代码/CLI/键名保持 ASCII 引号
- 专有名词保留英文：`Skills`、`Tailscale`、`Gateway` 等
- 代码块和内联代码保持原样，不做翻译

## 相关链接

- [OpenClaw 官网](https://openclaw.ai)
- [OpenClaw 官方文档](https://docs.openclaw.ai)
- [OpenClaw 主仓库](https://github.com/openclaw/openclaw)

## 许可证

本文档内容版权归 OpenClaw 项目所有。
