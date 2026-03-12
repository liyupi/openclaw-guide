---
summary: "`openclaw backup` CLI 参考（创建本地备份归档）"
read_when:
  - 需要为本地 OpenClaw 状态创建完整备份归档
  - 希望在重置或卸载前预览将包含哪些路径
title: "backup"
---

# `openclaw backup`

为 OpenClaw 的状态、配置、凭据、会话以及可选的工作区创建本地备份归档。

```bash
openclaw backup create
openclaw backup create --output ~/Backups
openclaw backup create --dry-run --json
openclaw backup create --verify
openclaw backup create --no-include-workspace
openclaw backup create --only-config
openclaw backup verify ./2026-03-09T00-00-00.000Z-openclaw-backup.tar.gz
```

## 注意事项

- 归档中包含一个 `manifest.json` 文件，记录了已解析的源路径和归档布局。
- 默认输出为当前工作目录下带时间戳的 `.tar.gz` 归档文件。
- 如果当前工作目录位于被备份的源目录树内，OpenClaw 会回退到主目录作为默认归档位置。
- 已存在的归档文件不会被覆盖。
- 位于源状态/工作区目录树内的输出路径会被拒绝，以避免自包含。
- `openclaw backup verify <archive>` 会验证归档中恰好包含一个根清单，拒绝包含路径遍历的归档路径，并检查清单中声明的每个有效负载是否存在于 tarball 中。
- `openclaw backup create --verify` 在写入归档后立即执行上述验证。
- `openclaw backup create --only-config` 仅备份当前活动的 JSON 配置文件。

## 备份内容

`openclaw backup create` 从本地 OpenClaw 安装中规划备份源：

- OpenClaw 本地状态解析器返回的状态目录，通常为 `~/.openclaw`
- 当前活动的配置文件路径
- OAuth / 凭据目录
- 从当前配置中发现的工作区目录，除非传入 `--no-include-workspace`

如果使用 `--only-config`，OpenClaw 会跳过状态、凭据和工作区发现，仅归档活动配置文件路径。

OpenClaw 在构建归档前会规范化路径。如果配置、凭据或工作区已位于状态目录内，则不会作为单独的顶层备份源重复包含。缺失的路径会被跳过。

归档有效负载存储来自这些源目录树的文件内容，嵌入的 `manifest.json` 记录了已解析的绝对源路径以及每个资产使用的归档布局。

## 无效配置行为

`openclaw backup` 故意绕过正常的配置预检，以便在恢复期间仍能提供帮助。由于工作区发现依赖有效配置，当配置文件存在但无效且工作区备份仍处于启用状态时，`openclaw backup create` 会快速失败。

如果在这种情况下仍需部分备份，请重新运行：

```bash
openclaw backup create --no-include-workspace
```

这样会保留状态、配置和凭据在范围内，同时完全跳过工作区发现。

如果只需要配置文件本身的副本，`--only-config` 在配置格式错误时也能正常工作，因为它不依赖解析配置来发现工作区。

## 大小与性能

OpenClaw 不强制内置的最大备份大小或单文件大小限制。

实际限制来自本地机器和目标文件系统：

- 临时归档写入和最终归档所需的可用空间
- 遍历大型工作区目录树并将其压缩为 `.tar.gz` 所需的时间
- 使用 `openclaw backup create --verify` 或运行 `openclaw backup verify` 时重新扫描归档所需的时间
- 目标路径的文件系统行为。OpenClaw 优先使用不覆盖的硬链接发布步骤，在不支持硬链接时回退到独占复制

大型工作区通常是归档大小的主要驱动因素。如果需要更小或更快的备份，请使用 `--no-include-workspace`。

要获得最小的归档，请使用 `--only-config`。
