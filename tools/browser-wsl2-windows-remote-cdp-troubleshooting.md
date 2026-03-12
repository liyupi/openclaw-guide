---
summary: "排查 WSL2 网关 + Windows Chrome 远程 CDP 和扩展中继设置的分层问题"
read_when:
  - 在 WSL2 中运行 OpenClaw 网关而 Chrome 在 Windows 上
  - 看到 WSL2 和 Windows 之间交叉的浏览器/控制 UI 错误
  - 在分离主机设置中选择原始远程 CDP 还是 Chrome 扩展中继
title: "WSL2 + Windows + remote Chrome CDP troubleshooting"
---

# WSL2 + Windows + 远程 Chrome CDP 故障排查

本指南涵盖常见的分离主机设置：

- OpenClaw 网关在 WSL2 内运行
- Chrome 在 Windows 上运行
- 浏览器控制必须跨越 WSL2/Windows 边界

本指南还涵盖来自 [issue #39369](https://github.com/openclaw/openclaw/issues/39369) 的分层故障模式：多个独立问题可能同时出现，导致错误的层看起来最先损坏。

## 首先选择正确的浏览器模式

你有两种有效的模式：

### 选项 1：原始远程 CDP

使用远程浏览器配置文件，从 WSL2 指向 Windows Chrome CDP 端点。

在以下情况选择此方式：

- 你只需要浏览器控制
- 你可以接受将 Chrome 远程调试暴露给 WSL2
- 你不需要 Chrome 扩展中继

### 选项 2：Chrome 扩展中继

使用内置的 `chrome` 配置文件加上 OpenClaw Chrome 扩展。

在以下情况选择此方式：

- 你想通过工具栏按钮附加到现有的 Windows Chrome 标签页
- 你想使用基于扩展的控制而非原始的 `--remote-debugging-port`
- 中继本身必须能跨越 WSL2/Windows 边界访问

如果你跨命名空间使用扩展中继，`browser.relayBindHost` 是在 [浏览器](/tools/browser) 和 [Chrome 扩展](/tools/chrome-extension) 中介绍的重要设置。

## 工作架构

参考架构：

- WSL2 在 `127.0.0.1:18789` 上运行网关
- Windows 在普通浏览器中打开控制 UI，地址为 `http://127.0.0.1:18789/`
- Windows Chrome 在端口 `9222` 上暴露 CDP 端点
- WSL2 可以到达该 Windows CDP 端点
- OpenClaw 将浏览器配置文件指向从 WSL2 可达的地址

## 为什么这种设置容易混淆

多个故障可能重叠：

- WSL2 无法到达 Windows CDP 端点
- 控制 UI 从非安全来源打开
- `gateway.controlUi.allowedOrigins` 与页面来源不匹配
- 缺少令牌或配对
- 浏览器配置文件指向错误的地址
- 扩展中继仍为仅回环模式，而你实际需要跨命名空间访问

因此，修复一层可能仍然留下不同的错误可见。

## 控制 UI 的关键规则

当从 Windows 打开 UI 时，除非你有专门的 HTTPS 设置，否则使用 Windows localhost。

使用：

`http://127.0.0.1:18789/`

不要默认使用局域网 IP 打开控制 UI。在局域网或 tailnet 地址上使用纯 HTTP 可能触发与 CDP 本身无关的不安全来源/设备认证行为。参阅[控制 UI](/web/control-ui)。

## 逐层验证

自上而下进行。不要跳过步骤。

### 第 1 层：验证 Chrome 在 Windows 上正在提供 CDP 服务

在 Windows 上启动启用远程调试的 Chrome：

```powershell
chrome.exe --remote-debugging-port=9222
```

从 Windows 先验证 Chrome 本身：

```powershell
curl http://127.0.0.1:9222/json/version
curl http://127.0.0.1:9222/json/list
```

如果这在 Windows 上失败，问题还不在 OpenClaw。

### 第 2 层：验证 WSL2 能到达该 Windows 端点

从 WSL2 测试你计划在 `cdpUrl` 中使用的确切地址：

```bash
curl http://WINDOWS_HOST_OR_IP:9222/json/version
curl http://WINDOWS_HOST_OR_IP:9222/json/list
```

正常结果：

- `/json/version` 返回包含 Browser / Protocol-Version 元数据的 JSON
- `/json/list` 返回 JSON（如果没有打开的页面，空数组也是正常的）

如果失败：

- Windows 尚未将端口暴露给 WSL2
- 地址对 WSL2 端来说不正确
- 防火墙/端口转发/本地代理仍然缺失

在修改 OpenClaw 配置之前先解决这个问题。

### 第 3 层：配置正确的浏览器配置文件

对于原始远程 CDP，将 OpenClaw 指向从 WSL2 可达的地址：

```json5
{
  browser: {
    enabled: true,
    defaultProfile: "remote",
    profiles: {
      remote: {
        cdpUrl: "http://WINDOWS_HOST_OR_IP:9222",
        attachOnly: true,
        color: "#00AA00",
      },
    },
  },
}
```

注意事项：

- 使用 WSL2 可达的地址，而非仅在 Windows 上有效的地址
- 对外部管理的浏览器保持 `attachOnly: true`
- 在期望 OpenClaw 成功之前，先用 `curl` 测试相同的 URL

### 第 4 层：如果你改用 Chrome 扩展中继

如果浏览器机器和网关被命名空间边界分隔，中继可能需要非回环绑定地址。

示例：

```json5
{
  browser: {
    enabled: true,
    defaultProfile: "chrome",
    relayBindHost: "0.0.0.0",
  },
}
```

仅在需要时使用：

- 默认行为更安全，因为中继保持仅回环模式
- `0.0.0.0` 扩大了暴露面
- 保持网关认证、节点配对和周围网络为私有

如果你不需要扩展中继，优先使用上面的原始远程 CDP 配置文件。

### 第 5 层：单独验证控制 UI 层

从 Windows 打开 UI：

`http://127.0.0.1:18789/`

然后验证：

- 页面来源与 `gateway.controlUi.allowedOrigins` 预期的匹配
- 令牌认证或配对配置正确
- 你没有把控制 UI 认证问题当作浏览器问题来调试

有帮助的页面：

- [控制 UI](/web/control-ui)

### 第 6 层：验证端到端浏览器控制

从 WSL2：

```bash
openclaw browser open https://example.com --browser-profile remote
openclaw browser tabs --browser-profile remote
```

对于扩展中继：

```bash
openclaw browser tabs --browser-profile chrome
```

正常结果：

- 标签页在 Windows Chrome 中打开
- `openclaw browser tabs` 返回目标
- 后续操作（`snapshot`、`screenshot`、`navigate`）在同一配置文件下正常工作

## 常见误导性错误

将每条消息视为层级特定的线索：

- `control-ui-insecure-auth`
  - UI 来源/安全上下文问题，不是 CDP 传输问题
- `token_missing`
  - 认证配置问题
- `pairing required`
  - 设备审批问题
- `Remote CDP for profile "remote" is not reachable`
  - WSL2 无法到达配置的 `cdpUrl`
- `gateway timeout after 1500ms`
  - 通常仍是 CDP 可达性问题或远程端点缓慢/不可达
- `Chrome extension relay is running, but no tab is connected`
  - 选择了扩展中继配置文件，但还没有附加的标签页

## 快速分诊检查清单

1. Windows：`curl http://127.0.0.1:9222/json/version` 是否工作？
2. WSL2：`curl http://WINDOWS_HOST_OR_IP:9222/json/version` 是否工作？
3. OpenClaw 配置：`browser.profiles.<name>.cdpUrl` 是否使用了该确切的 WSL2 可达地址？
4. 控制 UI：你是否打开的是 `http://127.0.0.1:18789/` 而非局域网 IP？
5. 仅扩展中继：你是否确实需要 `browser.relayBindHost`，如果需要，是否已显式设置？

## 实用要点

这种设置通常是可行的。困难在于浏览器传输、控制 UI 来源安全、令牌/配对和扩展中继拓扑可以各自独立失败，但从用户侧看起来很相似。

当有疑问时：

- 首先在 Windows 本地验证 Chrome 端点
- 其次从 WSL2 验证同一端点
- 然后才调试 OpenClaw 配置或控制 UI 认证
