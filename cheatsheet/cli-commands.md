---
title: "CLI 命令大全"
description: "OpenClaw 所有 CLI 命令的中文速查手册"
---

# 🦞 OpenClaw 命令大全

所有命令都有通俗易懂的中文解释，让你像查字典一样快速找到需要的操作。不用啃英文文档，直接查阅即可。

- 📌 基础格式：`openclaw <命令> [选项]`
- 🔗 官方文档：`docs.openclaw.ai/cli`

## 安装与初始化

### `openclaw setup`

首次安装后的初始化配置，创建配置文件和工作空间。

**通俗解释**：就像新买了一部手机第一次开机要设置语言、Wi-Fi 一样，`setup` 是你安装完 OpenClaw 后"第一次开机"的过程。它会帮你创建配置文件、设置工作目录。

**常用选项**：
- `--wizard` — 启动交互式引导向导（手把手教你配置）
- `--non-interactive` — 无人值守模式（不弹出提示，全自动）
- `--workspace <路径>` — 指定工作空间目录（默认 `~/.openclaw/workspace`）
- `--remote-url <地址>` — 连接远程 Gateway 的地址
- `--remote-token <令牌>` — 远程 Gateway 的认证令牌
- `--mode <模式>` — 选择向导模式

```bash
# 最简单的方式：启动交互式向导
$ openclaw setup --wizard

# 指定工作目录
$ openclaw setup --workspace ~/my-openclaw

# 连接远程服务器（无需交互）
$ openclaw setup --remote-url wss://my-server.com --remote-token xxx --non-interactive
```

### `openclaw onboard`

交互式新手引导向导，一步步带你设置 Gateway、工作空间和技能。

**通俗解释**：比 `setup` 更强大的"新手大礼包"——不仅创建配置，还会一步步引导你设置 Gateway 网关、聊天渠道、AI 模型密钥、技能等等。第一次用 OpenClaw 推荐跑这个。

**常用选项**：
- `--non-interactive` — 全自动无交互模式
- `--anthropic-api-key <key>` — 直接传入 Anthropic API Key
- `--openai-api-key <key>` — 直接传入 OpenAI API Key
- `--gemini-api-key <key>` — 直接传入 Gemini API Key
- `--openrouter-api-key <key>` — 直接传入 OpenRouter API Key
- `--gateway-port <端口>` — 指定 Gateway 端口
- `--skip-ui` — 跳过 UI 设置
- `--skip-channels` — 跳过聊天渠道设置
- `--skip-skills` — 跳过技能设置
- `--reset` — 先重置再开始向导
- `--install-daemon` — 安装后台守护进程

```bash
# 交互式引导（推荐新手）
$ openclaw onboard

# 非交互式，传入 API Key
$ openclaw onboard --non-interactive --anthropic-api-key sk-xxx --install-daemon

# 重置后重新引导
$ openclaw onboard --reset
```

### `openclaw doctor`

健康检查 + 自动修复（配置、Gateway、旧版迁移）。

**通俗解释**：相当于给小龙虾做一次"体检"——检查配置文件有没有问题、Gateway 是否正常、有没有需要迁移的旧版设置，发现问题还能自动帮你修。升级后建议跑一次。

**常用选项**：
- `--deep` — 深度扫描系统服务
- `--non-interactive` — 跳过提示，只应用安全迁移
- `--yes` — 全部同意默认选项（无头模式）
- `--no-workspace-suggestions` — 不显示工作空间记忆提示

```bash
$ openclaw doctor
$ openclaw doctor --deep
$ openclaw doctor --non-interactive --yes
```

## 配置管理

### `openclaw configure`

交互式配置向导（模型、渠道、技能、Gateway 一站式设置）。

**通俗解释**：打开一个"设置菜单"，像手机设置一样一项一项引导你配置模型、聊天渠道、技能、Gateway 等。适合想调整已有配置的用户。

```bash
$ openclaw configure
```

### `openclaw config get / set / unset`

读取、修改、删除配置项（精确控制单个配置值）。

**通俗解释**：像"微调旋钮"——不用打开整个设置向导，直接读取或修改某一项配置。路径格式支持点分隔（如 `gateway.auth.mode`）。

**子命令**：
- `config get <路径>` — 查看某个配置的当前值
- `config set <路径> <值>` — 设置配置值（支持 JSON5 或纯字符串）
- `config unset <路径>` — 删除某个配置
- `config file` — 显示配置文件路径
- `config validate` — 验证当前配置是否合法

```bash
# 查看 Gateway 端口
$ openclaw config get gateway.port

# 修改 Gateway 认证模式为 token
$ openclaw config set gateway.auth.mode token

# 删除某个配置
$ openclaw config unset gateway.auth.password

# 查看配置文件在哪里
$ openclaw config file

# 验证配置是否合法
$ openclaw config validate --json
```

### `openclaw dashboard`

打开 Web 管理面板。

**通俗解释**：在浏览器里打开一个可视化管理面板，不用记命令也能管理 OpenClaw。

```bash
$ openclaw dashboard
```

### `openclaw completion`

生成终端自动补全脚本（Tab 键补全命令）。

**通俗解释**：让你在终端输入 `openclaw` 后按 Tab 键就能自动补全命令，省得记那么多命令名。支持 bash、zsh、fish。

```bash
$ openclaw completion
```

## 聊天渠道管理

### `openclaw channels list`

列出已配置的所有聊天渠道和认证信息。

**通俗解释**：查看你的小龙虾连接了哪些聊天平台——WhatsApp、Telegram、Discord、Slack 等等，一目了然。

```bash
$ openclaw channels list
$ openclaw channels list --json
```

### `openclaw channels add`

添加新的聊天渠道（支持向导式或命令行传参）。

**通俗解释**：想让小龙虾接入 Telegram 或 Discord？用这个命令添加新渠道。不带参数会启动向导引导你一步步设置。

**常用选项**：
- `--channel <渠道名>` — whatsapp / telegram / discord / slack / signal / imessage / googlechat / msteams
- `--account <账号ID>` — 账号标识（默认 default）
- `--name <名称>` — 显示名称
- `--token <令牌>` — Bot Token

```bash
# 交互式添加
$ openclaw channels add

# 直接添加 Telegram Bot
$ openclaw channels add --channel telegram --account alerts --name "通知机器人" --token $TELEGRAM_BOT_TOKEN

# 添加 Discord Bot
$ openclaw channels add --channel discord --account work --name "工作助手" --token $DISCORD_BOT_TOKEN
```

### `openclaw channels remove`

移除已配置的聊天渠道。

**通俗解释**：不想用某个渠道了？用这个命令断开连接。默认只禁用，加 `--delete` 才是彻底删掉配置。

```bash
$ openclaw channels remove --channel discord --account work --delete
```

### `openclaw channels status`

检查各渠道的连接状态和健康情况。

**通俗解释**：相当于看看各个聊天平台的"信号灯"——连接正常亮绿灯，有问题会提示你怎么修。

```bash
$ openclaw channels status
$ openclaw channels status --probe  # 跑额外检查
```

### `openclaw channels login / logout`

登录或登出渠道（如 WhatsApp Web 扫码登录）。

**通俗解释**：有些渠道（如 WhatsApp）需要扫码登录才能用。这个命令就是帮你完成登录/登出操作的。

```bash
$ openclaw channels login --channel whatsapp
$ openclaw channels logout --channel whatsapp
```

### `openclaw channels logs`

查看渠道的最近日志（排查问题用）。

**通俗解释**：渠道连不上？消息发不出去？看看日志找线索。

```bash
$ openclaw channels logs
$ openclaw channels logs --channel telegram --lines 100
```

### `openclaw pairing list / approve`

管理渠道的 DM 配对请求（列出待审批、批准配对）。

**通俗解释**：当有人通过私聊(DM)想和你的小龙虾配对时，这里可以看到请求并决定是否批准。

```bash
$ openclaw pairing list
$ openclaw pairing approve --channel telegram --notify
```

### `openclaw qr`

显示 WhatsApp 登录二维码。

**通俗解释**：在终端里显示 WhatsApp Web 的二维码，用手机扫一扫就能登录。

```bash
$ openclaw qr
```

### `openclaw directory`

查看联系人/频道目录缓存。

**通俗解释**：列出小龙虾缓存的联系人和频道信息，方便你知道它"认识"谁。

```bash
$ openclaw directory
```

## Agent 智能体

### `openclaw agent`

运行一次 Agent 对话（通过 Gateway 或本地嵌入式）。

**通俗解释**：直接给 AI 智能体下达一条指令并获取回复。可以指定发送给谁、用哪个 session、甚至要求 AI "深度思考"。

**常用选项**：
- `--message <内容>` — **必填**，你要说的话
- `--to <目标>` — 发给谁（手机号、联系人等）
- `--agent <名称>` — 指定使用哪个 Agent
- `--deliver` — 发送后把回复投递给目标
- `--local` — 使用本地嵌入式模式（不走 Gateway）
- `--session-id <ID>` — 指定会话 ID（保持上下文）
- `--thinking <级别>` — 思考深度（仅支持部分模型）
- `--timeout <秒数>` — 超时时间

```bash
# 给联系人发消息并投递回复
$ openclaw agent --to +15555550123 --message "帮我查一下今天的天气" --deliver

# 用指定 Agent 跑任务
$ openclaw agent --agent ops --message "总结一下日志"

# 开启深度思考
$ openclaw agent --message "分析这个问题" --thinking medium
```

### `openclaw agents list`

列出所有已配置的 Agent 智能体。

**通俗解释**：看看你养了几只"小龙虾"——每个 Agent 都是一个独立的 AI 助手，有自己的工作空间和配置。

```bash
$ openclaw agents list
$ openclaw agents list --json --bindings
```

### `openclaw agents add`

创建新的隔离 Agent（独立工作空间 + 认证 + 路由）。

**通俗解释**：想要一个专门处理运维的 Agent 和一个专门回消息的 Agent？用这个命令创建新的独立智能体，每个有自己的"房间"（工作空间）。

```bash
# 交互式创建
$ openclaw agents add

# 非交互式创建，并绑定到 Telegram 渠道
$ openclaw agents add ops --workspace ~/agents/ops --bind telegram --non-interactive
```

### `openclaw agents delete`

删除一个 Agent 及其工作空间和状态。

```bash
$ openclaw agents delete ops
$ openclaw agents delete ops --force
```

### `openclaw agents bind / unbind`

为 Agent 添加或移除渠道路由绑定。

**通俗解释**：决定某个 Agent 负责哪个聊天渠道——比如让"运维 Agent"只处理 Slack 消息，让"客服 Agent"只处理 Telegram 消息。

```bash
# 绑定到 Slack 渠道
$ openclaw agents bind --agent ops --bind slack

# 解除所有绑定
$ openclaw agents unbind --agent ops --all
```

### `openclaw acp`

ACP 桥接 — 将 IDE 编辑器连接到 Gateway。

**通俗解释**：让你的代码编辑器（如 VS Code、Cursor）和 OpenClaw Gateway 对接，这样 AI 可以直接在 IDE 里帮你写代码。

```bash
$ openclaw acp
```

### `openclaw sessions`

列出已存储的对话会话。

**通俗解释**：查看小龙虾和谁聊过天、有哪些对话记录在"记忆"里。

```bash
$ openclaw sessions
$ openclaw sessions --json --verbose
```

### `openclaw tui`

打开终端交互界面（TUI），在命令行里和 Agent 聊天。

**通俗解释**：在终端里打开一个聊天窗口，直接和 AI 对话，不需要通过其他平台。适合开发者在命令行里快速提问。

```bash
$ openclaw tui
$ openclaw tui --message "帮我写一个 Python 脚本"
```

## 消息与发送

### `openclaw message send`

发送消息到指定渠道的指定目标（支持文字、图片、回复）。

**通俗解释**：从命令行直接发消息！可以发到 WhatsApp、Telegram、Discord、Slack 等任意已配置的平台。支持发文字、图片、回复消息等。

**常用选项**：
- `--channel <渠道>` — 发到哪个平台
- `--target <目标>` — 发给谁（频道ID / 用户ID / 手机号 等）
- `--message <内容>` — 消息内容
- `--media <文件>` — 附加图片/文件
- `--reply-to <消息ID>` — 回复某条消息
- `--thread-id <线程ID>` — 在特定线程中发送

```bash
# 给 WhatsApp 联系人发消息
$ openclaw message send --target +15555550123 --message "你好！"

# 在 Discord 频道发消息
$ openclaw message send --channel discord --target channel:123 --message "大家好"

# 回复某条消息
$ openclaw message send --channel discord --target channel:123 --message "收到" --reply-to 456
```

### `openclaw message poll`

创建投票（支持 WhatsApp / Telegram / Discord / Teams）。

**通俗解释**：在群里发起一个投票，比如"今天午餐吃什么？"——团队成员可以投票选择。

```bash
# Discord 投票
$ openclaw message poll --channel discord --target channel:123 \
  --poll-question "今天吃什么？" --poll-option 火锅 --poll-option 烧烤 --poll-multi

# Telegram 投票（2分钟自动关闭）
$ openclaw message poll --channel telegram --target @mychat \
  --poll-question "周末聚餐？" --poll-option 周六 --poll-option 周日 \
  --poll-duration-seconds 120
```

### `openclaw message react`

给消息添加/移除表情反应。

**通俗解释**：给某条消息点个"赞"或者加个表情反应，比如 ✅ 表示已处理。

```bash
$ openclaw message react --channel slack --target C123 --message-id 456 --emoji "✅"
$ openclaw message react --channel discord --target channel:123 --message-id 789 --emoji "👍"
```

### `openclaw message read / edit / delete / pin / search`

读取消息历史、编辑、删除、置顶、搜索消息。

**通俗解释**：全方位操作消息——翻看历史记录、编辑已发送的消息、删除消息、置顶重要消息、搜索频道内容。

**子命令**：
- `message read --target <目标>` — 读取消息历史
- `message edit --message-id <ID> --message <内容>` — 编辑消息
- `message delete --message-id <ID>` — 删除消息
- `message pin / unpin --message-id <ID>` — 置顶/取消置顶
- `message search --query <关键词>` — 搜索消息（Discord）

```bash
$ openclaw message read --channel slack --target C123 --limit 50
$ openclaw message search --channel discord --guild-id 123 --query "部署"
```

### `openclaw message thread create / list / reply`

管理 Discord 帖子/线程（创建、列出、回复）。

```bash
$ openclaw message thread create --channel discord --target channel:123 --thread-name "讨论帖"
$ openclaw message thread reply --channel discord --target 456 --message "同意！"
```

### `openclaw message broadcast`

群发消息给多个目标。

**通俗解释**：一次性给多个人或多个频道发消息，适合通知公告。支持 `--dry-run` 先预览不实际发送。

```bash
$ openclaw message broadcast --channel discord --targets channel:1 --targets channel:2 --message "系统维护通知"
```

### `openclaw message kick / ban / timeout`

Discord 管理操作 — 踢人、封禁、禁言。

```bash
$ openclaw message kick --channel discord --guild-id 123 --user-id 456 --reason "违规"
$ openclaw message ban --channel discord --guild-id 123 --user-id 456
$ openclaw message timeout --channel discord --guild-id 123 --user-id 456 --duration-min 30
```

## 模型管理

### `openclaw models status`

查看模型配置状态（认证信息、API Key 是否有效）。

**通俗解释**：检查你配置的 AI 模型（如 Claude、GPT、Gemini）的"健康状况"——API Key 是否过期、OAuth 是否正常、能不能正常调用。

**常用选项**：
- `--probe` — 发送实际请求测试模型（会消耗少量额度）
- `--check` — 只检查认证状态（不发请求）
- `--json` — JSON 格式输出

```bash
$ openclaw models status
$ openclaw models status --probe
```

### `openclaw models list`

列出所有可用模型。

```bash
$ openclaw models list
$ openclaw models list --provider openai
$ openclaw models list --local  # 只看本地模型
```

### `openclaw models set / set-image`

设置默认文本模型和图像模型。

**通俗解释**：决定小龙虾默认用哪个 AI 大脑来思考和画图。

```bash
# 设置默认文本模型
$ openclaw models set claude-sonnet-4-20250514

# 设置默认图像模型
$ openclaw models set-image dall-e-3
```

### `openclaw models scan`

自动扫描和发现可用的 AI 模型。

**通俗解释**：让小龙虾自动"嗅探"你的 API Key 能用哪些模型，省得手动一个个配置。

```bash
$ openclaw models scan
$ openclaw models scan --set-default --yes  # 扫描并自动设为默认
```

### `openclaw models auth add / setup-token / paste-token`

添加或配置模型 API 认证信息。

**通俗解释**：告诉小龙虾你的 API Key 或 Token，这样它才能调用各家 AI 模型。

**子命令**：
- `auth add` — 交互式添加认证
- `auth setup-token --provider anthropic` — 自动设置 Anthropic Token
- `auth paste-token --provider <名称>` — 手动粘贴 Token

```bash
$ openclaw models auth add
$ openclaw models auth setup-token --provider anthropic --yes
```

### `openclaw models fallbacks / image-fallbacks`

设置模型故障转移（主模型挂了自动切换到备选）。

**通俗解释**：给 AI 模型设置"候补队员"——如果主力模型挂了或者限速了，自动换一个备用模型继续工作。

```bash
$ openclaw models fallbacks list
$ openclaw models fallbacks add gpt-4o
$ openclaw models fallbacks remove gpt-4o
$ openclaw models fallbacks clear
```

### `openclaw models aliases`

管理模型别名（给长模型名起个简短的昵称）。

```bash
$ openclaw models aliases list
$ openclaw models aliases add claude claude-sonnet-4-20250514
```

### `openclaw models auth order get / set / clear`

管理模型提供商的认证优先级顺序。

**通俗解释**：当多个提供商都有同样的模型时，决定先用谁的——比如优先用 Anthropic 直连，不行再用 OpenRouter。

```bash
$ openclaw models auth order get
$ openclaw models auth order set anthropic openrouter
$ openclaw models auth order clear
```

## Gateway 网关

### `openclaw gateway / gateway run`

前台启动 Gateway WebSocket 服务。

**通俗解释**：Gateway 是小龙虾的"神经中枢"——所有消息收发、AI 调用、工具执行都通过它。这个命令启动它（前台模式，关掉终端就停）。

**常用选项**：
- `--port <端口>` — 指定端口（默认 18789）
- `--token <令牌>` — 设置认证 Token
- `--password <密码>` — 设置认证密码
- `--force` — 强制启动（杀掉占用端口的进程）
- `--verbose` — 输出详细日志
- `--dev` — 开发模式
- `--tailscale <模式>` — 通过 Tailscale 暴露

```bash
$ openclaw gateway
$ openclaw gateway --port 8080 --force --verbose
```

### `openclaw gateway install / start / stop / restart / uninstall`

管理 Gateway 后台服务（安装、启动、停止、重启、卸载）。

**通俗解释**：把 Gateway 装成后台服务——开机自动启动，关掉终端也不会停。就像把程序设成"开机自启"。

```bash
# 安装为系统服务
$ openclaw gateway install

# 启动/停止/重启
$ openclaw gateway start
$ openclaw gateway stop
$ openclaw gateway restart

# 卸载服务
$ openclaw gateway uninstall
```

### `openclaw gateway status / health / probe`

查看 Gateway 运行状态和健康情况。

**通俗解释**：
- `status` — 综合状态（服务 + 探测）
- `health` — 简单健康检查
- `probe` — "全面体检"，同时探测本地和远程网关

```bash
$ openclaw gateway status
$ openclaw gateway health --json
$ openclaw gateway probe  # 最全面的诊断
```

### `openclaw gateway call`

底层 RPC 调用（直接调用 Gateway 接口）。

**通俗解释**：高级玩法——直接调用 Gateway 的底层接口。适合脚本化操作或调试。

```bash
$ openclaw gateway call status
$ openclaw gateway call logs.tail --params '{"sinceMs": 60000}'
$ openclaw gateway call config.patch --params '{"data": {"some": "value"}}'
```

### `openclaw gateway discover`

在局域网中发现其他 Gateway 实例（Bonjour / mDNS）。

**通俗解释**：在同一个局域网内"搜索"是否有其他 OpenClaw Gateway 在运行，方便多设备互联。

```bash
$ openclaw gateway discover
$ openclaw gateway discover --json --timeout 4000
```

## 浏览器控制

### `openclaw browser start / stop / status`

启动、停止、查看浏览器控制服务。

**通俗解释**：让小龙虾能控制一个浏览器——打开网页、点按钮、截图等等。支持 Chrome、Brave、Edge。

```bash
$ openclaw browser start
$ openclaw browser status
$ openclaw browser stop
```

### `openclaw browser tabs / open / close / focus`

管理浏览器标签页（查看、打开、关闭、切换）。

```bash
$ openclaw browser tabs  # 查看所有标签页
$ openclaw browser open https://github.com  # 打开网页
$ openclaw browser focus abc123  # 切换到某个标签
$ openclaw browser close abc123  # 关闭标签
```

### `openclaw browser screenshot / snapshot`

截图或获取页面结构快照。

**通俗解释**：
- `screenshot` — 截取网页图片
- `snapshot` — 获取页面的 DOM/ARIA 结构（供 AI 理解页面内容）

```bash
$ openclaw browser screenshot --full-page
$ openclaw browser snapshot --format ai
```

### `openclaw browser navigate / click / type / hover / drag`

浏览器自动化操作（导航、点击、输入、悬停、拖拽）。

**通俗解释**：让小龙虾像人一样操作网页——打开链接、点按钮、填表单、拖拽元素。

```bash
$ openclaw browser navigate https://example.com
$ openclaw browser click ref123  # 点击元素
$ openclaw browser type ref456 "Hello World"  # 输入文字
$ openclaw browser fill --fields '{"name":"张三","email":"test@test.com"}'
```

### `openclaw browser profiles / create-profile / delete-profile`

管理浏览器配置文件（隔离不同的浏览器环境）。

**通俗解释**：每个 profile 是一个独立的浏览器环境——不同的 Cookie、登录状态等。可以一个用来办公，一个用来测试。

```bash
$ openclaw browser profiles
$ openclaw browser create-profile --name work --color "#FF5A36"
$ openclaw browser --browser-profile work tabs
```

### `openclaw browser pdf / evaluate / console`

导出 PDF、执行 JS 脚本、查看控制台输出。

```bash
$ openclaw browser pdf  # 将当前页面导出为 PDF
$ openclaw browser evaluate --fn "document.title"  # 执行 JS
$ openclaw browser console  # 查看控制台日志
```

## Node 节点

### `openclaw node run / install / start / stop / status`

运行或管理 Node Host 服务（远程设备上的代理）。

**通俗解释**：Node Host 就像你在另一台电脑上安排的"分身"——让 Gateway 可以远程控制那台机器上的浏览器、执行命令等。

```bash
$ openclaw node run --host my-server.com --port 18789
$ openclaw node install --host my-server.com --port 18789
$ openclaw node status
```

### `openclaw nodes list / status / approve / reject`

管理已连接的远程节点（查看、审批、拒绝）。

```bash
$ openclaw nodes list
$ openclaw nodes status --connected
$ openclaw nodes approve <requestId>
$ openclaw nodes pending  # 查看待审批节点
```

### `openclaw nodes run / invoke / notify`

在远程节点上执行命令、发送通知。

**通俗解释**：远程遥控其他机器——在节点上跑命令、发通知，就像 SSH 但通过 OpenClaw Gateway。

```bash
# 在远程节点执行命令
$ openclaw nodes run --node my-mac "ls -la"

# 发送通知到节点
$ openclaw nodes notify --node my-mac --title "提醒" --body "部署完成！"
```

### `openclaw nodes camera snap / clip / list`

远程控制节点摄像头（拍照、录像）。

```bash
$ openclaw nodes camera list --node my-mac
$ openclaw nodes camera snap --node my-mac --facing front
$ openclaw nodes camera clip --node my-mac --duration 10
```

### `openclaw nodes screen / canvas / location`

远程录屏、Canvas 画布控制、获取位置信息。

```bash
$ openclaw nodes screen record --node my-mac --duration 30
$ openclaw nodes canvas snapshot --node my-mac
$ openclaw nodes location get --node my-iphone
```

### `openclaw devices list / approve / remove / rotate`

管理设备配对和令牌。

```bash
$ openclaw devices list
$ openclaw devices approve <requestId>
$ openclaw devices remove <deviceId>
$ openclaw devices rotate --device abc --role admin
```

## 定时任务

### `openclaw cron add`

创建定时任务（按时间间隔或 cron 表达式）。

**通俗解释**：像设闹钟一样——让小龙虾在固定时间自动做某件事，比如每天早上 9 点发一条状态报告。

**常用选项**：
- `--name <名称>` — 任务名称（必填）
- `--at <时间>` — 指定时间执行一次
- `--every <间隔>` — 每隔多久执行一次（如 `1h`、`30m`）
- `--cron <表达式>` — 标准 cron 表达式
- `--system-event <文本>` — 触发系统事件
- `--message <内容>` — 发送消息

```bash
# 每小时触发一次系统事件
$ openclaw cron add --name "hourly-check" --every 1h --system-event "执行例行检查"

# 每天早上9点发消息
$ openclaw cron add --name "morning-report" --cron "0 9 * * *" --message "早安！请查看今日待办"
```

### `openclaw cron list / status`

查看所有定时任务及其运行状态。

```bash
$ openclaw cron list
$ openclaw cron list --all --json
$ openclaw cron status
```

### `openclaw cron edit / rm / enable / disable / runs / run`

编辑、删除、启用/禁用、查看运行记录、手动执行定时任务。

```bash
$ openclaw cron edit myJob --every 2h  # 改为每2小时
$ openclaw cron disable myJob  # 暂时关闭
$ openclaw cron enable myJob   # 重新开启
$ openclaw cron runs --id myJob  # 查看运行历史
$ openclaw cron run myJob --force  # 手动触发一次
$ openclaw cron rm myJob  # 删除任务
```

### `openclaw hooks list / info / enable / disable / install`

管理事件钩子（Hooks）——事件触发自动执行。

**通俗解释**：Hooks 就像"触发器"——当某个事件发生时（比如收到消息、文件变化），自动执行预设的操作。

```bash
$ openclaw hooks list
$ openclaw hooks info myHook
$ openclaw hooks enable myHook
$ openclaw hooks disable myHook
```

### `openclaw webhooks gmail setup / run`

设置和运行 Gmail 邮件 Webhook（有新邮件自动通知）。

```bash
$ openclaw webhooks gmail setup --account myGmail
$ openclaw webhooks gmail run
```

### `openclaw approvals / sandbox`

管理操作审批策略和沙箱环境。

**通俗解释**：
- `approvals` — 控制哪些操作需要人工审批、设置白名单
- `sandbox` — 管理沙箱环境（AI 在安全隔离的环境中执行操作）

```bash
$ openclaw approvals get
$ openclaw approvals set --auto  # 自动审批
$ openclaw approvals allowlist add "safe-command"
$ openclaw sandbox list
$ openclaw sandbox explain
```

## 记忆与搜索

### `openclaw memory search / index / status`

管理 AI 记忆库（语义搜索、索引、状态查看）。

**通俗解释**：小龙虾的"记忆"存储在 `MEMORY.md` 和 `memory/*.md` 文件中。你可以用语义搜索快速找到以前记住的信息。

```bash
$ openclaw memory search "上次部署出了什么问题？"
$ openclaw memory index  # 重建索引
$ openclaw memory status  # 查看索引状态
```

## 插件管理

### `openclaw plugins list / info / install / enable / disable / doctor`

管理插件（列出、安装、启用、禁用、排查问题）。

**通俗解释**：插件就像给小龙虾装"外挂"——扩展新功能。比如语音通话插件 `voicecall`。

```bash
$ openclaw plugins list
$ openclaw plugins info voicecall
$ openclaw plugins install voicecall
$ openclaw plugins enable voicecall
$ openclaw plugins disable voicecall
$ openclaw plugins doctor  # 排查插件加载错误
```

<Tip>大部分插件操作完后需要重启 Gateway 才能生效。</Tip>

## 技能管理

### `openclaw skills list / info / check`

管理 AI 技能（列出、查看详情、检查就绪状态）。

**通俗解释**：技能是 AI 的"特长"——比如搜索网页、操作文件、发邮件等。这里可以看看小龙虾会哪些技能、哪些还没准备好。

```bash
$ openclaw skills list
$ openclaw skills list --eligible  # 只看可用的
$ openclaw skills info web-search
$ openclaw skills check  # 检查哪些技能缺依赖
```

<Tip>使用 `npx clawhub` 可以搜索、安装和同步更多技能。</Tip>

## 安全与密钥

### `openclaw security audit`

安全审计（检查配置漏洞、文件权限、Gateway 安全性）。

**通俗解释**：给小龙虾做一次"安全体检"——查找配置里的安全隐患，检查文件权限是否过于宽松。

```bash
$ openclaw security audit
$ openclaw security audit --fix   # 自动修复安全问题
$ openclaw security audit --deep  # 深度探测 Gateway
```

### `openclaw secrets reload / configure / audit`

管理密钥和敏感信息（重新加载、配置、审计）。

**通俗解释**：管理 API Key、Token 等敏感信息。支持用环境变量引用（SecretRef）来避免明文存储。

```bash
$ openclaw secrets reload  # 重新加载密钥
$ openclaw secrets configure  # 交互式配置密钥管理
$ openclaw secrets audit  # 扫描明文残留
```

## 系统监控

### `openclaw status`

查看整体状态（Gateway + 渠道 + 用量 综合诊断）。

**通俗解释**：一条命令看全局——Gateway 是否在线、渠道连接状态、最近联系人、API 用量等。

```bash
$ openclaw status
$ openclaw status --deep    # 探测所有渠道
$ openclaw status --usage   # 查看 API 用量
$ openclaw status --all     # 完整诊断（可粘贴分享）
```

### `openclaw health`

快速检查 Gateway 是否存活。

```bash
$ openclaw health
$ openclaw health --json
```

### `openclaw logs`

查看 Gateway 日志（实时跟踪或历史查看）。

**通俗解释**：出了问题先看日志！支持实时跟踪（`--follow`），就像看直播一样盯着运行状态。

```bash
$ openclaw logs
$ openclaw logs --follow  # 实时跟踪
$ openclaw logs --limit 200  # 最近200条
$ openclaw logs --json  # JSON 格式
```

### `openclaw system event / heartbeat / presence`

系统事件、心跳管理、在线状态查询。

**通俗解释**：
- `system event --text "..."` — 发送一个系统事件（触发 AI 处理）
- `system heartbeat last` — 查看最后一次心跳
- `system heartbeat enable/disable` — 开启/关闭心跳
- `system presence` — 查看系统在线状态

```bash
$ openclaw system event --text "检查服务器状态"
$ openclaw system heartbeat last
$ openclaw system presence
```

## 维护与卸载

### `openclaw update`

更新 OpenClaw 到最新版本。

**通俗解释**：一键升级小龙虾到最新版本。也可以用 `openclaw --update` 快捷方式。

```bash
$ openclaw update
```

### `openclaw backup create / verify`

创建和验证配置/数据备份。

**通俗解释**：重要操作前先备份——万一搞砸了还能恢复。

```bash
$ openclaw backup create
$ openclaw backup verify
```

### `openclaw reset`

重置本地配置和状态（CLI 保留，数据清空）。

**通俗解释**："恢复出厂设置"——清除配置和数据，但不卸载程序。适合从头开始重新配置。

**常用选项**：
- `--scope <范围>` — 指定重置范围
- `--yes` — 确认执行
- `--dry-run` — 只预览不实际执行

```bash
$ openclaw reset --dry-run  # 先看看会清除什么
$ openclaw reset --yes
```

### `openclaw uninstall`

卸载 Gateway 服务和本地数据（CLI 保留）。

**通俗解释**：卸载 Gateway 服务并清理数据。注意：CLI 程序本身不会被删除，只是清理了服务和数据。

**常用选项**：
- `--all` — 全部清除
- `--service` — 只卸载服务
- `--state` — 只清除状态数据
- `--workspace` — 只清除工作空间
- `--dry-run` — 预览模式

```bash
$ openclaw uninstall --dry-run
$ openclaw uninstall --all --yes
```

## 其他工具

### `openclaw docs [关键词]`

搜索官方文档。

**通俗解释**：不用打开浏览器，直接在命令行搜索官方文档。

```bash
$ openclaw docs gateway
$ openclaw docs "how to setup telegram"
```

### `openclaw dns setup`

设置 DNS 发现（CoreDNS + Tailscale 广域发现）。

```bash
$ openclaw dns setup
$ openclaw dns setup --apply  # 安装配置（需 sudo，仅 macOS）
```

### `openclaw --version / -V`

查看当前安装的 OpenClaw 版本。

```bash
$ openclaw --version
$ openclaw -V
```

### 全局选项 `--no-color / --profile / --dev / --json`

所有命令都支持的全局选项。

**通俗解释**：这些选项可以加在任何命令后面：
- `--no-color` — 关闭彩色输出（方便复制日志）
- `--profile <名称>` — 使用独立配置文件（多环境隔离）
- `--dev` — 开发模式（隔离状态到 `~/.openclaw-dev`）
- `--json` — 输出 JSON 格式（方便脚本处理）

```bash
$ openclaw status --json
$ openclaw --profile staging gateway status
$ openclaw --dev gateway run
```
