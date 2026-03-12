---
summary: "`openclaw secrets` CLI 参考（重新加载、审计、配置、应用）"
read_when:
  - 在运行时重新解析 secret ref
  - 审计明文残留和未解析的 ref
  - 配置 SecretRef 并应用单向清理变更
title: "secrets"
---

# `openclaw secrets`

使用 `openclaw secrets` 管理 SecretRef 并保持活动运行时快照的健康状态。

命令角色：

- `reload`：Gateway 网关 RPC（`secrets.reload`），重新解析 ref 并仅在全部成功时交换运行时快照（不写入配置）。
- `audit`：对配置/认证/生成模型存储及旧版残留进行只读扫描，检查明文、未解析 ref 和优先级漂移。
- `configure`：用于提供者设置、目标映射和预检的交互式规划器（需要 TTY）。
- `apply`：执行已保存的计划（`--dry-run` 仅验证），然后清理目标明文残留。

推荐的运维流程：

```bash
openclaw secrets audit --check
openclaw secrets configure
openclaw secrets apply --from /tmp/openclaw-secrets-plan.json --dry-run
openclaw secrets apply --from /tmp/openclaw-secrets-plan.json
openclaw secrets audit --check
openclaw secrets reload
```

CI/门禁的退出码说明：

- `audit --check` 发现问题时返回 `1`。
- 未解析的 ref 返回 `2`。

相关文档：

- 密钥管理指南：[密钥管理](/gateway/secrets)
- 凭据表面：[SecretRef 凭据表面](/reference/secretref-credential-surface)
- 安全指南：[安全](/gateway/security)

## 重新加载运行时快照

重新解析 secret ref 并原子化交换运行时快照。

```bash
openclaw secrets reload
openclaw secrets reload --json
```

注意事项：

- 使用 Gateway 网关 RPC 方法 `secrets.reload`。
- 如果解析失败，Gateway 网关会保留上次已知良好的快照并返回错误（不会部分激活）。
- JSON 响应包含 `warningCount`。

## 审计

扫描 OpenClaw 状态以检查：

- 明文密钥存储
- 未解析的 ref
- 优先级漂移（`auth-profiles.json` 凭据遮蔽 `openclaw.json` ref）
- 生成的 `agents/*/agent/models.json` 残留（提供者 `apiKey` 值和敏感提供者头信息）
- 旧版残留（旧版认证存储条目、OAuth 提醒）

头信息残留说明：

- 敏感提供者头信息检测基于名称启发式（常见的认证/凭据头名称和片段，如 `authorization`、`x-api-key`、`token`、`secret`、`password` 和 `credential`）。

```bash
openclaw secrets audit
openclaw secrets audit --check
openclaw secrets audit --json
```

退出行为：

- `--check` 发现问题时以非零状态退出。
- 未解析的 ref 以更高优先级的非零状态码退出。

报告结构要点：

- `status`：`clean | findings | unresolved`
- `summary`：`plaintextCount`、`unresolvedRefCount`、`shadowedRefCount`、`legacyResidueCount`
- 发现代码：
  - `PLAINTEXT_FOUND`
  - `REF_UNRESOLVED`
  - `REF_SHADOWED`
  - `LEGACY_RESIDUE`

## 配置（交互式助手）

交互式构建提供者和 SecretRef 变更，运行预检，并可选地应用：

```bash
openclaw secrets configure
openclaw secrets configure --plan-out /tmp/openclaw-secrets-plan.json
openclaw secrets configure --apply --yes
openclaw secrets configure --providers-only
openclaw secrets configure --skip-provider-setup
openclaw secrets configure --agent ops
openclaw secrets configure --json
```

流程：

- 首先进行提供者设置（对 `secrets.providers` 别名执行 `add/edit/remove`）。
- 然后进行凭据映射（选择字段并分配 `{source, provider, id}` ref）。
- 最后进行预检和可选的应用。

标志：

- `--providers-only`：仅配置 `secrets.providers`，跳过凭据映射。
- `--skip-provider-setup`：跳过提供者设置，将凭据映射到现有提供者。
- `--agent <id>`：将 `auth-profiles.json` 目标发现和写入限定为单个代理存储。

注意事项：

- 需要交互式 TTY。
- 不能同时使用 `--providers-only` 和 `--skip-provider-setup`。
- `configure` 针对 `openclaw.json` 中的密钥承载字段以及所选代理范围的 `auth-profiles.json`。
- `configure` 支持在选择器流程中直接创建新的 `auth-profiles.json` 映射。
- 支持的规范表面：[SecretRef 凭据表面](/reference/secretref-credential-surface)。
- 在应用前执行预检解析。
- 生成的计划默认启用清理选项（`scrubEnv`、`scrubAuthProfilesForProviderTargets`、`scrubLegacyAuthJson` 全部启用）。
- 对于已清理的明文值，应用路径是单向的。
- 不使用 `--apply` 时，CLI 在预检后仍会提示 `Apply this plan now?`。
- 使用 `--apply`（且不使用 `--yes`）时，CLI 会额外提示一次不可逆确认。

exec 提供者安全说明：

- Homebrew 安装通常在 `/opt/homebrew/bin/*` 下暴露符号链接的二进制文件。
- 仅在需要信任的包管理器路径时设置 `allowSymlinkCommand: true`，并与 `trustedDirs`（例如 `["/opt/homebrew"]`）配合使用。
- 在 Windows 上，如果 ACL 验证对某个提供者路径不可用，OpenClaw 会安全失败。仅对受信任的路径，在该提供者上设置 `allowInsecurePath: true` 以绕过路径安全检查。

## 应用已保存的计划

应用或预检之前生成的计划：

```bash
openclaw secrets apply --from /tmp/openclaw-secrets-plan.json
openclaw secrets apply --from /tmp/openclaw-secrets-plan.json --dry-run
openclaw secrets apply --from /tmp/openclaw-secrets-plan.json --json
```

计划契约详情（允许的目标路径、验证规则和失败语义）：

- [密钥应用计划契约](/gateway/secrets-plan-contract)

`apply` 可能更新的内容：

- `openclaw.json`（SecretRef 目标 + 提供者更新/删除）
- `auth-profiles.json`（提供者目标清理）
- 旧版 `auth.json` 残留
- `~/.openclaw/.env` 中值已迁移的已知密钥键

## 为什么没有回滚备份

`secrets apply` 故意不写入包含旧明文值的回滚备份。

安全性来自严格的预检 + 原子化应用，在失败时进行尽力而为的内存恢复。

## 示例

```bash
openclaw secrets audit --check
openclaw secrets configure
openclaw secrets audit --check
```

如果 `audit --check` 仍报告明文发现，请更新剩余报告的目标路径并重新运行审计。
