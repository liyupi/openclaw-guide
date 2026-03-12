---
title: "Prompt Caching"
summary: "提示缓存的调节旋钮、合并顺序、提供商行为和调优模式"
read_when:
  - 希望通过缓存保留减少提示 token 成本时
  - 需要多代理场景中每代理的缓存行为时
  - 同时调优心跳和 cache-ttl 剪枝时
---

# 提示缓存

提示缓存意味着模型提供商可以跨轮次复用未更改的提示前缀（通常是系统/开发者指令和其他稳定上下文），而不是每次都重新处理。第一个匹配的请求写入缓存 token（`cacheWrite`），后续匹配的请求可以读回它们（`cacheRead`）。

为什么重要：更低的 token 成本、更快的响应和长时间运行会话中更可预测的性能。没有缓存时，重复的提示在每个轮次都要支付完整的提示成本，即使大部分输入没有改变。

本页面涵盖影响提示复用和 token 成本的所有缓存相关调节旋钮。

关于 Anthropic 定价详情，参见：
[https://docs.anthropic.com/docs/build-with-claude/prompt-caching](https://docs.anthropic.com/docs/build-with-claude/prompt-caching)

## 主要旋钮

### `cacheRetention`（模型和每代理）

在模型参数上设置缓存保留：

```yaml
agents:
  defaults:
    models:
      "anthropic/claude-opus-4-6":
        params:
          cacheRetention: "short" # none | short | long
```

每代理覆盖：

```yaml
agents:
  list:
    - id: "alerts"
      params:
        cacheRetention: "none"
```

配置合并顺序：

1. `agents.defaults.models["provider/model"].params`
2. `agents.list[].params`（匹配代理 ID；按键覆盖）

### 旧版 `cacheControlTtl`

旧值仍然被接受并映射：

- `5m` -> `short`
- `1h` -> `long`

新配置请优先使用 `cacheRetention`。

### `contextPruning.mode: "cache-ttl"`

在缓存 TTL 窗口后剪枝旧的工具结果上下文，使空闲后的请求不会重新缓存过大的历史记录。

```yaml
agents:
  defaults:
    contextPruning:
      mode: "cache-ttl"
      ttl: "1h"
```

完整行为参见[会话剪枝](/concepts/session-pruning)。

### 心跳保温

心跳可以保持缓存窗口温热，减少空闲间隔后的重复缓存写入。

```yaml
agents:
  defaults:
    heartbeat:
      every: "55m"
```

每代理心跳在 `agents.list[].heartbeat` 中支持。

## 提供商行为

### Anthropic（直接 API）

- 支持 `cacheRetention`。
- 使用 Anthropic API-key 认证配置时，OpenClaw 在未设置时为 Anthropic 模型引用种子 `cacheRetention: "short"`。

### Amazon Bedrock

- Anthropic Claude 模型引用（`amazon-bedrock/*anthropic.claude*`）支持显式 `cacheRetention` 透传。
- 非 Anthropic Bedrock 模型在运行时强制为 `cacheRetention: "none"`。

### OpenRouter Anthropic 模型

对于 `openrouter/anthropic/*` 模型引用，OpenClaw 在系统/开发者提示块上注入 Anthropic `cache_control` 以改善提示缓存复用。

### 其他提供商

如果提供商不支持此缓存模式，`cacheRetention` 无效果。

## 调优模式

### 混合流量（推荐默认）

在主代理上保持长期基线，在突发通知代理上禁用缓存：

```yaml
agents:
  defaults:
    model:
      primary: "anthropic/claude-opus-4-6"
    models:
      "anthropic/claude-opus-4-6":
        params:
          cacheRetention: "long"
  list:
    - id: "research"
      default: true
      heartbeat:
        every: "55m"
    - id: "alerts"
      params:
        cacheRetention: "none"
```

### 成本优先基线

- 设置基线 `cacheRetention: "short"`。
- 启用 `contextPruning.mode: "cache-ttl"`。
- 仅对受益于温热缓存的代理将心跳保持在 TTL 以下。

## 缓存诊断

OpenClaw 为嵌入式代理运行暴露专用的缓存追踪诊断。

### `diagnostics.cacheTrace` 配置

```yaml
diagnostics:
  cacheTrace:
    enabled: true
    filePath: "~/.openclaw/logs/cache-trace.jsonl" # 可选
    includeMessages: false # 默认 true
    includePrompt: false # 默认 true
    includeSystem: false # 默认 true
```

默认值：

- `filePath`：`$OPENCLAW_STATE_DIR/logs/cache-trace.jsonl`
- `includeMessages`：`true`
- `includePrompt`：`true`
- `includeSystem`：`true`

### 环境变量开关（一次性调试）

- `OPENCLAW_CACHE_TRACE=1` 启用缓存追踪。
- `OPENCLAW_CACHE_TRACE_FILE=/path/to/cache-trace.jsonl` 覆盖输出路径。
- `OPENCLAW_CACHE_TRACE_MESSAGES=0|1` 切换完整消息负载捕获。
- `OPENCLAW_CACHE_TRACE_PROMPT=0|1` 切换提示文本捕获。
- `OPENCLAW_CACHE_TRACE_SYSTEM=0|1` 切换系统提示捕获。

### 检查内容

- 缓存追踪事件为 JSONL 格式，包含分阶段快照如 `session:loaded`、`prompt:before`、`stream:context` 和 `session:after`。
- 每轮次的缓存 token 影响在正常使用界面中通过 `cacheRead` 和 `cacheWrite` 可见（例如 `/usage full` 和会话使用量摘要）。

## 快速故障排除

- 大多数轮次出现高 `cacheWrite`：检查系统提示输入是否有波动内容，并确认模型/提供商支持你的缓存设置。
- `cacheRetention` 无效果：确认模型键匹配 `agents.defaults.models["provider/model"]`。
- 带缓存设置的 Bedrock Nova/Mistral 请求：预期运行时强制为 `none`。

相关文档：

- [Anthropic](/providers/anthropic)
- [Token 使用和成本](/reference/token-use)
- [会话剪枝](/concepts/session-pruning)
- [网关配置参考](/gateway/configuration-reference)
