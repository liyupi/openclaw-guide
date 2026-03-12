---
title: "斜杠命令大全"
description: "OpenClaw 所有斜杠命令的中文速查手册"
---

# ⚡ 斜杠命令速查手册

在聊天中输入 `/命令` 就能操控小龙虾。本文整理了所有斜杠命令的通俗中文说明，让你一看就懂、随查随用。

支持 WhatsApp / Telegram / Discord / Slack / 飞书 等平台。

## 🔥 核心高频命令

### `/new`

**别名**：`/reset`

开始一段全新的对话，清空当前会话记忆。

**通俗解释**

聊天聊了很久、上下文乱了、或者想换个话题？发 `/new` 就是"翻开新一页" —— 小龙虾会忘掉之前的对话，从头开始。

**用法**

- `/new` — 直接开始新对话
- `/new claude-sonnet-4-20250514` — 开始新对话，顺便切换到指定模型
- `/reset` — 效果和 `/new` 一样

**示例**

```
# 直接重置
你发送：/new
🦞 回复：Session reset. Ready for a new conversation.

# 重置并切换模型
你发送：/new gpt-4o
🦞 回复：Session reset. Model set to gpt-4o.
```

### `/help`

查看所有可用命令的帮助信息。

**通俗解释**

忘了有什么命令？发 `/help` 小龙虾就会列出所有可用的命令和简要说明。

**示例**

```
你发送：/help
```

<Tip>
`/help` 可以嵌入到普通消息中使用，比如 `帮我查一下 /help 有什么命令`，帮助信息会单独返回，剩余的文字照常处理。
</Tip>

### `/status`

查看小龙虾当前状态（模型、用量、连接等）。

**通俗解释**

相当于给小龙虾做个快速"体检" —— 看看当前用的什么模型、API 额度还剩多少、连接是否正常。

**示例**

```
你发送：/status
🦞 回复：模型、连接状态、API 用量等信息
```

<Tip>
也可以内嵌使用：`帮我看看 /status 然后继续回答上面的问题`
</Tip>

### `/commands`

列出所有已注册的命令。

和 `/help` 类似，列出当前可用的所有命令。

### `/whoami`

**别名**：`/id`

查看你在当前渠道的身份标识（Sender ID）。

**通俗解释**

查看小龙虾是怎么认识你的 —— 返回你在当前聊天平台上的用户 ID，设置白名单时会用到。

**示例**

```
你发送：/whoami
🦞 回复：你的 Sender ID（如 user:123456）
```

### `/stop`

停止当前正在运行的任务。

**通俗解释**

小龙虾正在跑一个很长的任务但你不想等了？发 `/stop` 立刻打断它。

### `/skill <技能名> [参数]`

直接调用某个技能。

**通俗解释**

跳过 AI 判断，直接告诉小龙虾"用某个技能做事" —— 比如直接搜索网页、发邮件等。

**示例**

```
你发送：/skill web-search 今天天气
```

<Tip>
标记为 `user-invocable` 的技能会自动注册为斜杠命令（如 `/web_search`），可以直接用。
</Tip>

## 💬 会话管理

### `/compact [指令]`

压缩当前对话上下文（解决对话过长的问题）。

**通俗解释**

聊了太久，上下文变得很长很贵？`/compact` 会把前面的对话内容"浓缩"成摘要，保留核心信息但大幅缩短上下文长度。

**示例**

```
# 直接压缩
你发送：/compact

# 给压缩过程一些指示
你发送：/compact 请重点保留关于数据库设计的讨论
```

### `/export-session [路径]`

**别名**：`/export`

将当前对话导出为 HTML 文件。

**通俗解释**

想保存聊天记录？这个命令会把完整的对话（包括系统提示词）导出成一个好看的 HTML 文件。

**示例**

```
你发送：/export-session
你发送：/export ~/chats/my-session.html
```

### `/context [list|detail|json]`

查看当前上下文的组成和大小。

**通俗解释**

好奇小龙虾的"脑容量"被什么占了？这个命令告诉你系统提示词、工具、技能各占了多少 token。

**用法**

- `/context` — 概览
- `/context detail` — 详细分类（每个文件、工具、技能的大小）
- `/context json` — JSON 格式输出

### `/queue [选项]`

管理消息队列设置（防抖、容量、丢弃策略）。

**通俗解释**

连续发了好几条消息？`/queue` 控制小龙虾怎么处理它们 —— 是等一下合并处理，还是逐条回复。

**示例**

```
# 查看当前队列设置
你发送：/queue

# 设置防抖2秒、最多25条、超出的做摘要
你发送：/queue debounce:2s cap:25 drop:summarize
```

## 🧠 模型切换

### `/model [模型名|编号|list|status]`

**别名**：`/models`

查看或切换当前使用的 AI 模型。

**通俗解释**

想换个"大脑"？用 `/model` 切换小龙虾使用的 AI 模型 —— 比如从 Claude 换到 GPT。

**用法**

- `/model` — 显示模型列表，带编号的选择器
- `/model list` — 列出所有可用模型
- `/model 3` — 选择列表中的第 3 个模型
- `/model gpt-4o` — 直接指定模型名
- `/model openai/gpt-5.2` — 指定提供商/模型
- `/model status` — 查看模型详细状态（含认证、端点信息）

**示例**

```
你发送：/model
🦞 回复：1. Claude Sonnet  2. GPT-4o  3. Gemini Pro ...

你发送：/model 1
🦞 回复：Model set to claude-sonnet-4-20250514

你发送：/model gpt-4o
🦞 回复：Model set to gpt-4o
```

<Tip>
在 Discord 上，`/model` 会弹出交互式下拉菜单，可以选提供商和模型。
</Tip>

### `/think <级别>`

**别名**：`/thinking`、`/t`

控制 AI 的"思考深度"（越高越仔细，也越慢越贵）。

**通俗解释**

让 AI 多想想再回答，还是快速给结果？`/think` 控制思考的投入程度。级别越高，回答越深入但速度越慢、花费越多。

**注意**：这是一个"指令" —— 可以单独发也可以嵌入到消息中。

**示例**

```
# 作为单独指令（设置会持续生效）
你发送：/think high

# 嵌入到消息中（只对这条消息生效）
你发送：/think high 帮我分析这个复杂的算法

# 关闭深度思考
你发送：/think off
```

<Tip>
可用的级别取决于模型/提供商，常见有 `low`、`medium`、`high`。部分模型不支持此功能。
</Tip>

## 📊 输出控制

### `/verbose on|full|off`

**别名**：`/v`

控制输出的详细程度（显示工具调用细节、错误详情等）。

**通俗解释**

正常模式下小龙虾只告诉你结果。开了 `/verbose` 就像开了"幕后花絮" —— 能看到工具调用详情、错误信息等。排查问题时很有用。

**用法**

- `/verbose off` — 关闭（默认，只看结果）
- `/verbose on` — 显示工具调用详情和错误信息
- `/verbose full` — 显示一切（最详细）

**示例**

```
你发送：/verbose on
你发送：/v full
```

<Warning>
群聊慎用！开启后可能暴露内部工具输出和推理过程。建议仅在私聊中调试使用。
</Warning>

### `/reasoning on|off|stream`

**别名**：`/reason`

控制是否显示 AI 的推理过程。

**通俗解释**

想看看 AI 是怎么一步步想出答案的？开启后会额外发一条以"Reasoning:"开头的消息，展示思维链。

**用法**

- `/reasoning on` — 显示推理过程（单独消息）
- `/reasoning stream` — 流式显示推理（仅 Telegram 草稿支持）
- `/reasoning off` — 关闭

<Warning>
群聊慎用！推理内容可能包含你不想公开的内部信息。
</Warning>

### `/usage off|tokens|full|cost`

控制是否在回复后显示 Token 消耗和费用。

**通俗解释**

想知道每条回复花了多少 Token 和钱？打开这个功能，小龙虾会在每次回复后附上用量统计。

**用法**

- `/usage off` — 关闭用量显示
- `/usage tokens` — 只显示 Token 数
- `/usage full` — 显示完整用量信息
- `/usage cost` — 显示本地费用汇总

**示例**

```
你发送：/usage full
# 之后每条回复末尾都会显示 token 消耗
```

### `/tts off|always|inbound|tagged|status|provider|limit|summary|audio`

控制文字转语音功能（让小龙虾"说出来"）。

**通俗解释**

让回复不仅是文字，还能自动转成语音播放。适合不方便看屏幕的时候使用。

**用法**

- `/tts always` — 所有回复都转语音
- `/tts off` — 关闭语音
- `/tts status` — 查看当前 TTS 状态

<Tip>
Discord 上原生命令名为 `/voice`（因为 Discord 保留了 `/tts`），但文本方式发 `/tts` 依然有效。
</Tip>

### `/send on|off|inherit`

控制是否将回复投递给目标用户（仅 Owner）。

**通俗解释**

有时候你想让 AI 帮你编辑消息但先不发出去。`/send off` 就是"只给我看，别发出去"。

## 🤖 Agent / 子代理管理

### `/subagents list|kill|log|info|send|steer|spawn`

查看、控制、启动当前会话的子代理。

**通俗解释**

小龙虾在处理复杂任务时可能会派出"小弟"（子代理）。这个命令让你管理这些小弟。

**用法**

- `/subagents list` — 列出当前运行的子代理
- `/subagents kill` — 终止子代理
- `/subagents log` — 查看子代理日志
- `/subagents info` — 查看子代理详情
- `/subagents steer` — 给子代理新的指示
- `/subagents spawn` — 手动启动子代理

### `/steer <指示>`

**别名**：`/tell`

给正在运行的子代理发送即时指示。

**通俗解释**

子代理在做任务的时候，你突然想改方向？`/steer` 可以"插嘴" —— 如果子代理还在跑，就立刻改方向；如果已经做完了，就打断重新来。

**示例**

```
你发送：/steer 不要用 Python 了，换成 TypeScript
```

### `/kill [名称]`

立即终止一个或所有正在运行的子代理。

不废话直接杀掉，没有确认提示。

### `/acp spawn|cancel|steer|close|status|set-mode|...`

检查和控制 ACP（IDE 桥接）运行时会话。

**通俗解释**

ACP 是 OpenClaw 和 IDE（如 Cursor、VS Code）的桥梁。这个命令让你管理 ACP 会话 —— 启动、关闭、查看状态等。

**用法**

- `/acp status` — 查看 ACP 状态
- `/acp spawn` — 启动新 ACP 会话
- `/acp cancel` — 取消会话
- `/acp sessions` — 列出会话
- `/acp doctor` — 诊断 ACP 问题

### `/approve allow-once|allow-always|deny`

处理工具执行的审批请求。

**通俗解释**

小龙虾想执行一个需要审批的操作（比如运行命令、修改文件），它会问你"可以吗？"。用这个命令回答。

**用法**

- `/approve allow-once` — 这次允许
- `/approve allow-always` — 以后都允许这类操作
- `/approve deny` — 拒绝

### `/elevated on|off|ask|full`

**别名**：`/elev`

控制工具的权限级别（是否需要审批）。

**通俗解释**

控制小龙虾执行操作时的权限 —— 是每次都问你、自动执行、还是完全不允许。

**用法**

- `/elevated off` — 关闭提权
- `/elevated ask` — 每次都问你
- `/elevated on` — 开启提权
- `/elevated full` — 完全开放（连执行审批都跳过）

### `/exec [host=... security=... ask=... node=...]`

查看或设置工具执行策略。

不带参数发 `/exec` 查看当前策略，带参数修改执行设置。

## 🎮 Discord 专属

### `/focus <目标>`

将当前 Discord 线程绑定到特定会话/子代理。

**通俗解释**

把一个 Discord 线程"锁定"到某个会话上 —— 这个线程里的所有消息都发给指定的 Agent。

### `/unfocus`

解除当前线程的绑定。

解除 `/focus` 的绑定，让线程恢复正常路由。

### `/agents`

列出当前会话中线程绑定的 Agent。

查看当前会话有哪些线程绑定了哪些 Agent。

### `/session idle <时间>` 和 `/session max-age <时间>`

设置线程绑定的自动过期时间。

**用法**

- `/session idle 30m` — 空闲 30 分钟后自动解绑
- `/session max-age 2h` — 最多存活 2 小时后自动解绑

### `/activation mention|always`

设置群组中机器人的响应模式。

**用法**

- `/activation mention` — 只有 @机器人 时才回复（默认）
- `/activation always` — 每条消息都回复

### `/dock-discord`、`/dock-telegram`、`/dock-slack`

将回复渠道切换到指定平台。

**通俗解释**

在 Telegram 里聊天，但想让回复发到 Slack 上？用 `/dock-slack` 切换。

## 🔧 管理员命令

### `/debug show|set|unset|reset`

运行时临时覆盖配置（仅存在内存，不写磁盘）。

**通俗解释**

想临时改个配置试试效果，但不想影响配置文件？`/debug` 就是"临时贴纸" —— 改了立刻生效，重启后消失。

**示例**

```
# 查看当前临时覆盖
你发送：/debug show

# 临时设置回复前缀
你发送：/debug set messages.responsePrefix="[test]"

# 取消某项覆盖
你发送：/debug unset messages.responsePrefix

# 清除所有临时覆盖
你发送：/debug reset
```

<Warning>
需要先在配置中启用 `commands.debug: true`，仅 Owner 可用。
</Warning>

### `/config show|get|set|unset`

在聊天中直接读写配置文件（永久生效）。

**通俗解释**

不用 SSH 到服务器编辑文件！直接在聊天里修改 `openclaw.json` 配置，改完立即生效且重启后还在。

**示例**

```
# 查看所有配置
你发送：/config show

# 查看某项配置
你发送：/config get messages.responsePrefix

# 设置配置值
你发送：/config set messages.responsePrefix="[openclaw]"

# 删除配置值
你发送：/config unset messages.responsePrefix
```

<Warning>
需要先在配置中启用 `commands.config: true`，仅 Owner 可用。修改会自动校验，非法值会被拒绝。
</Warning>

### `/allowlist [add|remove]`

管理允许使用机器人的用户白名单。

查看、添加或移除白名单条目。需要 `commands.config: true`。

### `/restart`

重启 Gateway 进程。

在聊天里直接重启 Gateway。默认启用，可通过 `commands.restart: false` 禁用。

## 🖥️ Shell / Bash 命令

### `! <命令>`

**别名**：`/bash <命令>`

在主机上直接执行 Shell 命令。

**通俗解释**

直接在聊天里跑终端命令！比如 `! ls -la` 或 `! docker ps`。一次只能跑一个命令。

**示例**

```
你发送：! ls -la /home
你发送：/bash docker ps
你发送：! top -n 1
```

<Warning>
需要在配置中启用 `commands.bash: true`，且需要 `tools.elevated` 白名单授权。务必谨慎使用！
</Warning>

### `!poll`

**别名**：`/bash poll`

查看正在运行的 bash 命令的输出/状态。

命令跑了太久被放到后台了？用 `!poll` 看看它的最新输出。

### `!stop`

**别名**：`/bash stop`

停止正在运行的 bash 命令。

命令跑飞了想终止？用 `!stop`。

## 📚 其他命令

### `/restart`

在聊天中重启 Gateway。

默认开启。可通过 `commands.restart: false` 禁用。

## 📖 核心概念说明

### 命令 vs 指令

OpenClaw 的斜杠操作分为两种：

- **命令（Commands）**：必须作为单独消息发送（如 `/help`、`/new`），会立即执行并返回结果
- **指令（Directives）**：可以嵌入到普通消息中（如 `/think high 帮我分析`），会从消息中剥离出来单独处理，剩余文字照常发给 AI

指令包括：`/think`、`/verbose`、`/reasoning`、`/elevated`、`/exec`、`/model`、`/queue`

### 指令的两种用法

- **单独发送**（如 `/verbose on`）→ 设置会**持久保存**到会话中，后续所有消息都生效
- **嵌入消息**（如 `/verbose on 帮我查bug`）→ 作为"临时提示"，**不会**持久保存

### 内联快捷命令

这几个命令可以嵌入到普通消息中使用（不需要单独发）：`/help`、`/commands`、`/status`、`/whoami`（`/id`）

例如：`帮我看看 /status 然后写个脚本` → 状态信息会单独返回，"写个脚本"照常处理。

### 权限控制

并非所有人都能用所有命令。权限规则：

- 如果配置了 `commands.allowFrom`，只有白名单中的用户能使用命令和指令
- 否则使用渠道自身的白名单/配对授权 + `commands.useAccessGroups`
- 未授权用户发的斜杠命令会被当作普通文本处理

### 冒号语法

命令和参数之间可以用冒号分隔（可选）：`/think: high`、`/send: on`、`/help:`
