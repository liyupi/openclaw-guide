---
title: health
---
从运行中的 Gateway 网关获取健康状态。

```bash
openclaw health
openclaw health --json
openclaw health --verbose
```

注意：

- `--verbose` 运行实时探测，并在配置了多个账户时打印每个账户的耗时。
- 当配置了多个智能体时，输出包括每个智能体的会话存储。
