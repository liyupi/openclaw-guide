---
summary: "`openclaw completion` CLI 参考（生成/安装 shell 补全脚本）"
read_when:
  - 需要 zsh/bash/fish/PowerShell 的 shell 补全
  - 需要将补全脚本缓存到 OpenClaw 状态目录
title: "completion"
---

# `openclaw completion`

生成 shell 补全脚本，并可选地将其安装到你的 shell 配置文件中。

## 用法

```bash
openclaw completion
openclaw completion --shell zsh
openclaw completion --install
openclaw completion --shell fish --install
openclaw completion --write-state
openclaw completion --shell bash --write-state
```

## 选项

- `-s, --shell <shell>`：目标 shell（`zsh`、`bash`、`powershell`、`fish`；默认：`zsh`）
- `-i, --install`：通过在 shell 配置文件中添加 source 行来安装补全
- `--write-state`：将补全脚本写入 `$OPENCLAW_STATE_DIR/completions`，不输出到标准输出
- `-y, --yes`：跳过安装确认提示

## 注意事项

- `--install` 会在你的 shell 配置文件中写入一个小的 "OpenClaw Completion" 块，并将其指向缓存的脚本。
- 不使用 `--install` 或 `--write-state` 时，命令会将脚本输出到标准输出。
- 补全生成会预加载命令树，以便包含嵌套的子命令。
