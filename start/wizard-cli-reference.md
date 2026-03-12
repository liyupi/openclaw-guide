---
summary: "CLI 引导流程、认证/模型设置、输出和内部实现的完整参考"
read_when:
  - 你需要 openclaw onboard 的详细行为
  - 你在调试引导结果或集成引导客户端
title: "CLI Onboarding Reference"
sidebarTitle: "CLI 参考"
---

# CLI 引导参考

本页是 `openclaw onboard` 的完整参考。
简短指南请参见[引导向导（CLI）](/start/wizard)。

## 向导执行的操作

本地模式（默认）会引导你完成：

- 模型和认证设置（OpenAI Code 订阅 OAuth、Anthropic API key 或 setup token，以及 MiniMax、GLM、Moonshot 和 AI Gateway 选项）
- 工作区位置和引导文件
- Gateway 设置（端口、绑定、认证、Tailscale）
- 频道和提供者（Telegram、WhatsApp、Discord、Google Chat、Mattermost 插件、Signal）
- 守护进程安装（LaunchAgent 或 systemd 用户单元）
- 健康检查
- Skills 设置

远程模式配置此机器连接到其他地方的 Gateway。
它不会在远程主机上安装或修改任何内容。

## 本地流程详情

<Steps>
  <Step title="现有配置检测">
    - 如果 `~/.openclaw/openclaw.json` 存在，选择保留、修改或重置。
    - 重新运行向导不会擦除任何内容，除非你明确选择重置（或传递 `--reset`）。
    - CLI `--reset` 默认为 `config+creds+sessions`；使用 `--reset-scope full` 也可移除工作区。
    - 如果配置无效或包含遗留键，向导会停止并要求你在继续之前运行 `openclaw doctor`。
    - 重置使用 `trash` 并提供范围选择：
      - 仅配置
      - 配置 + 凭据 + 会话
      - 完全重置（同时移除工作区）
  </Step>
  <Step title="模型和认证">
    - 完整的选项矩阵在[认证和模型选项](#认证和模型选项)中。
  </Step>
  <Step title="工作区">
    - 默认 `~/.openclaw/workspace`（可配置）。
    - 为首次运行引导仪式播种工作区文件。
    - 工作区布局：[代理工作区](/concepts/agent-workspace)。
  </Step>
  <Step title="Gateway">
    - 提示输入端口、绑定、认证模式和 Tailscale 暴露。
    - 建议：即使是 loopback 也保持令牌认证启用，这样本地 WS 客户端必须认证。
    - 在令牌模式下，交互式引导提供：
      - **生成/存储明文令牌**（默认）
      - **使用 SecretRef**（选择性启用）
    - 在密码模式下，交互式引导也支持明文或 SecretRef 存储。
    - 非交互式令牌 SecretRef 路径：`--gateway-token-ref-env <ENV_VAR>`。
      - 需要在引导进程环境中有非空的环境变量。
      - 不能与 `--gateway-token` 组合使用。
    - 仅在你完全信任每个本地进程时才禁用认证。
    - 非 loopback 绑定仍然需要认证。
  </Step>
  <Step title="频道">
    - [WhatsApp](/channels/whatsapp)：可选 QR 登录
    - [Telegram](/channels/telegram)：bot token
    - [Discord](/channels/discord)：bot token
    - [Google Chat](/channels/googlechat)：服务账户 JSON + webhook audience
    - [Mattermost](/channels/mattermost) 插件：bot token + base URL
    - [Signal](/channels/signal)：可选 `signal-cli` 安装 + 账户配置
    - [BlueBubbles](/channels/bluebubbles)：推荐用于 iMessage；服务器 URL + 密码 + webhook
    - [iMessage](/channels/imessage)：旧版 `imsg` CLI 路径 + 数据库访问
    - DM 安全：默认为配对。首条 DM 发送代码；通过 `openclaw pairing approve <channel> <code>` 批准或使用允许列表。
  </Step>
  <Step title="守护进程安装">
    - macOS：LaunchAgent
      - 需要已登录的用户会话；对于无头服务器，使用自定义 LaunchDaemon（未随附）。
    - Linux 和 Windows（通过 WSL2）：systemd 用户单元
      - 向导尝试 `loginctl enable-linger <user>` 使 Gateway 在注销后保持运行。
      - 可能提示输入 sudo（写入 `/var/lib/systemd/linger`）；它会先尝试不使用 sudo。
    - 运行时选择：Node（推荐；WhatsApp 和 Telegram 必需）。不推荐 Bun。
  </Step>
  <Step title="健康检查">
    - 启动 Gateway（如需要）并运行 `openclaw health`。
    - `openclaw status --deep` 为状态输出添加 Gateway 健康探测。
  </Step>
  <Step title="Skills">
    - 读取可用 Skills 并检查要求。
    - 让你选择 node 管理器：npm 或 pnpm（不推荐 bun）。
    - 安装可选依赖（某些在 macOS 上使用 Homebrew）。
  </Step>
  <Step title="完成">
    - 摘要和后续步骤，包括 iOS、Android 和 macOS 应用选项。
  </Step>
</Steps>

<Note>
如果未检测到 GUI，向导会打印 SSH 端口转发指令以访问 Control UI，而不是打开浏览器。
如果 Control UI 资源缺失，向导会尝试构建它们；回退方案是 `pnpm ui:build`（自动安装 UI 依赖）。
</Note>

## 远程模式详情

远程模式配置此机器连接到其他地方的 Gateway。

<Info>
远程模式不会在远程主机上安装或修改任何内容。
</Info>

你需要设置：

- 远程 Gateway URL（`ws://...`）
- 令牌（如果远程 Gateway 认证是必需的，推荐启用）

<Note>
- 如果 Gateway 仅限 loopback，使用 SSH 隧道或 tailnet。
- 发现提示：
  - macOS：Bonjour（`dns-sd`）
  - Linux：Avahi（`avahi-browse`）
</Note>

## 认证和模型选项

<AccordionGroup>
  <Accordion title="Anthropic API key">
    如果存在 `ANTHROPIC_API_KEY` 则使用它，否则提示输入 key，然后保存以供守护进程使用。
  </Accordion>
  <Accordion title="Anthropic OAuth（Claude Code CLI）">
    - macOS：检查 Keychain 项 "Claude Code-credentials"
    - Linux 和 Windows：如果存在则复用 `~/.claude/.credentials.json`

    在 macOS 上，选择 "Always Allow" 以确保 launchd 启动不会被阻止。

  </Accordion>
  <Accordion title="Anthropic token（setup-token 粘贴）">
    在任何机器上运行 `claude setup-token`，然后粘贴令牌。
    你可以命名它；留空使用默认名称。
  </Accordion>
  <Accordion title="OpenAI Code 订阅（Codex CLI 复用）">
    如果 `~/.codex/auth.json` 存在，向导可以复用它。
  </Accordion>
  <Accordion title="OpenAI Code 订阅（OAuth）">
    浏览器流程；粘贴 `code#state`。

    当模型未设置或为 `openai/*` 时，设置 `agents.defaults.model` 为 `openai-codex/gpt-5.4`。

  </Accordion>
  <Accordion title="OpenAI API key">
    如果存在 `OPENAI_API_KEY` 则使用它，否则提示输入 key，然后将凭据存储在 auth profiles 中。

    当模型未设置、为 `openai/*` 或 `openai-codex/*` 时，设置 `agents.defaults.model` 为 `openai/gpt-5.1-codex`。

  </Accordion>
  <Accordion title="xAI（Grok）API key">
    提示输入 `XAI_API_KEY` 并将 xAI 配置为模型提供者。
  </Accordion>
  <Accordion title="OpenCode">
    提示输入 `OPENCODE_API_KEY`（或 `OPENCODE_ZEN_API_KEY`），让你选择 Zen 或 Go catalog。
    设置 URL：[opencode.ai/auth](https://opencode.ai/auth)。
  </Accordion>
  <Accordion title="API key（通用）">
    为你存储 key。
  </Accordion>
  <Accordion title="Vercel AI Gateway">
    提示输入 `AI_GATEWAY_API_KEY`。
    更多详情：[Vercel AI Gateway](/providers/vercel-ai-gateway)。
  </Accordion>
  <Accordion title="Cloudflare AI Gateway">
    提示输入 account ID、gateway ID 和 `CLOUDFLARE_AI_GATEWAY_API_KEY`。
    更多详情：[Cloudflare AI Gateway](/providers/cloudflare-ai-gateway)。
  </Accordion>
  <Accordion title="MiniMax M2.5">
    配置自动写入。
    更多详情：[MiniMax](/providers/minimax)。
  </Accordion>
  <Accordion title="Synthetic（Anthropic 兼容）">
    提示输入 `SYNTHETIC_API_KEY`。
    更多详情：[Synthetic](/providers/synthetic)。
  </Accordion>
  <Accordion title="Moonshot 和 Kimi Coding">
    Moonshot（Kimi K2）和 Kimi Coding 配置自动写入。
    更多详情：[Moonshot AI（Kimi + Kimi Coding）](/providers/moonshot)。
  </Accordion>
  <Accordion title="自定义提供者">
    适用于 OpenAI 兼容和 Anthropic 兼容端点。

    交互式引导支持与其他提供者 API key 流程相同的 API key 存储选择：
    - **立即粘贴 API key**（明文）
    - **使用密钥引用**（环境变量引用或已配置的提供者引用，带预检验证）

    非交互式标志：
    - `--auth-choice custom-api-key`
    - `--custom-base-url`
    - `--custom-model-id`
    - `--custom-api-key`（可选；回退到 `CUSTOM_API_KEY`）
    - `--custom-provider-id`（可选）
    - `--custom-compatibility <openai|anthropic>`（可选；默认 `openai`）

  </Accordion>
  <Accordion title="跳过">
    不配置认证。
  </Accordion>
</AccordionGroup>

模型行为：

- 从检测到的选项中选择默认模型，或手动输入提供者和模型。
- 向导运行模型检查，当配置的模型未知或缺少认证时发出警告。

凭据和配置文件路径：

- OAuth 凭据：`~/.openclaw/credentials/oauth.json`
- Auth profiles（API keys + OAuth）：`~/.openclaw/agents/<agentId>/agent/auth-profiles.json`

凭据存储模式：

- 默认引导行为将 API key 作为明文值持久化到 auth profiles 中。
- `--secret-input-mode ref` 启用引用模式，替代明文 key 存储。
  在交互式引导中，你可以选择：
  - 环境变量引用（例如 `keyRef: { source: "env", provider: "default", id: "OPENAI_API_KEY" }`）
  - 已配置的提供者引用（`file` 或 `exec`），带提供者别名 + id
- 交互式引用模式在保存前运行快速预检验证。
  - 环境变量引用：验证变量名 + 当前引导环境中的非空值。
  - 提供者引用：验证提供者配置并解析请求的 id。
  - 如果预检失败，引导显示错误并让你重试。
- 在非交互模式下，`--secret-input-mode ref` 仅支持环境变量。
  - 在引导进程环境中设置提供者环境变量。
  - 内联 key 标志（例如 `--openai-api-key`）需要该环境变量已设置；否则引导会快速失败。
  - 对于自定义提供者，非交互式 `ref` 模式将 `models.providers.<id>.apiKey` 存储为 `{ source: "env", provider: "default", id: "CUSTOM_API_KEY" }`。
  - 在该自定义提供者场景中，`--custom-api-key` 需要 `CUSTOM_API_KEY` 已设置；否则引导会快速失败。
- Gateway 认证凭据在交互式引导中支持明文和 SecretRef 选择：
  - 令牌模式：**生成/存储明文令牌**（默认）或**使用 SecretRef**。
  - 密码模式：明文或 SecretRef。
- 非交互式令牌 SecretRef 路径：`--gateway-token-ref-env <ENV_VAR>`。
- 现有明文设置继续正常工作。

<Note>
无头服务器提示：在有浏览器的机器上完成 OAuth，然后将
`~/.openclaw/credentials/oauth.json`（或 `$OPENCLAW_STATE_DIR/credentials/oauth.json`）
复制到 Gateway 主机。
</Note>

## 输出和内部实现

`~/.openclaw/openclaw.json` 中的典型字段：

- `agents.defaults.workspace`
- `agents.defaults.model` / `models.providers`（如果选择了 Minimax）
- `tools.profile`（本地引导在未设置时默认为 `"coding"`；现有的显式值被保留）
- `gateway.*`（mode、bind、auth、tailscale）
- `session.dmScope`（本地引导在未设置时默认为 `per-channel-peer`；现有的显式值被保留）
- `channels.telegram.botToken`、`channels.discord.token`、`channels.signal.*`、`channels.imessage.*`
- 频道允许列表（Slack、Discord、Matrix、Microsoft Teams），当你在提示中选择启用时（名称在可能时解析为 ID）
- `skills.install.nodeManager`
- `wizard.lastRunAt`
- `wizard.lastRunVersion`
- `wizard.lastRunCommit`
- `wizard.lastRunCommand`
- `wizard.lastRunMode`

`openclaw agents add` 写入 `agents.list[]` 和可选的 `bindings`。

WhatsApp 凭据存储在 `~/.openclaw/credentials/whatsapp/<accountId>/` 下。
会话存储在 `~/.openclaw/agents/<agentId>/sessions/` 下。

<Note>
某些频道作为插件提供。在引导过程中选择时，向导会提示安装插件（npm 或本地路径），然后再进行频道配置。
</Note>

Gateway 向导 RPC：

- `wizard.start`
- `wizard.next`
- `wizard.cancel`
- `wizard.status`

客户端（macOS 应用和 Control UI）可以渲染步骤而无需重新实现引导逻辑。

Signal 设置行为：

- 下载相应的发布资源
- 存储在 `~/.openclaw/tools/signal-cli/<version>/` 下
- 在配置中写入 `channels.signal.cliPath`
- JVM 构建需要 Java 21
- 可用时使用原生构建
- Windows 使用 WSL2 并在 WSL 内遵循 Linux signal-cli 流程

## 相关文档

- 引导中心：[引导向导（CLI）](/start/wizard)
- 自动化和脚本：[CLI 自动化](/start/wizard-cli-automation)
- 命令参考：[`openclaw onboard`](/cli/onboard)
