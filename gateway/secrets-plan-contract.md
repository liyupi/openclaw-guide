---
summary: "`secrets apply` 计划的契约：目标验证、路径匹配和 `auth-profiles.json` 目标范围"
read_when:
  - 生成或审查 `openclaw secrets apply` 计划
  - 调试 `Invalid plan target path` 错误
  - 了解目标类型和路径验证行为
title: "Secrets Apply Plan Contract"
---

# Secrets apply 计划契约

本页定义了 `openclaw secrets apply` 执行的严格契约。

如果目标不匹配这些规则，apply 会在修改配置之前失败。

## 计划文件结构

`openclaw secrets apply --from <plan.json>` 需要一个包含计划目标的 `targets` 数组：

```json5
{
  version: 1,
  protocolVersion: 1,
  targets: [
    {
      type: "models.providers.apiKey",
      path: "models.providers.openai.apiKey",
      pathSegments: ["models", "providers", "openai", "apiKey"],
      providerId: "openai",
      ref: { source: "env", provider: "default", id: "OPENAI_API_KEY" },
    },
    {
      type: "auth-profiles.api_key.key",
      path: "profiles.openai:default.key",
      pathSegments: ["profiles", "openai:default", "key"],
      agentId: "main",
      ref: { source: "env", provider: "default", id: "OPENAI_API_KEY" },
    },
  ],
}
```

## 支持的目标范围

计划目标适用于以下文档中支持的凭据路径：

- [SecretRef 凭据表面](/reference/secretref-credential-surface)

## 目标类型行为

一般规则：

- `target.type` 必须被识别，且必须与规范化的 `target.path` 结构匹配。

兼容性别名仍然适用于现有计划：

- `models.providers.apiKey`
- `skills.entries.apiKey`
- `channels.googlechat.serviceAccount`

## 路径验证规则

每个目标都通过以下所有验证：

- `type` 必须是已识别的目标类型。
- `path` 必须是非空的点分路径。
- `pathSegments` 可以省略。如果提供，它必须规范化为与 `path` 完全相同的路径。
- 禁止的段会被拒绝：`__proto__`、`prototype`、`constructor`。
- 规范化路径必须与目标类型的注册路径结构匹配。
- 如果设置了 `providerId` 或 `accountId`，它必须与路径中编码的 id 匹配。
- `auth-profiles.json` 目标需要 `agentId`。
- 创建新的 `auth-profiles.json` 映射时，需要包含 `authProfileProvider`。

## 失败行为

如果目标验证失败，apply 会以如下错误退出：

```text
Invalid plan target path for models.providers.apiKey: models.providers.openai.baseUrl
```

无效计划不会执行任何写入。

## 运行时和审计范围说明

- 仅包含引用的 `auth-profiles.json` 条目（`keyRef`/`tokenRef`）包含在运行时解析和审计覆盖范围内。
- `secrets apply` 写入支持的 `openclaw.json` 目标、支持的 `auth-profiles.json` 目标和可选的清除目标。

## 操作者检查

```bash
# Validate plan without writes
openclaw secrets apply --from /tmp/openclaw-secrets-plan.json --dry-run

# Then apply for real
openclaw secrets apply --from /tmp/openclaw-secrets-plan.json
```

如果 apply 因无效目标路径消息而失败，请使用 `openclaw secrets configure` 重新生成计划或将目标路径修改为上述支持的结构。

## 相关文档

- [密钥管理](/gateway/secrets)
- [CLI `secrets`](/cli/secrets)
- [SecretRef 凭据表面](/reference/secretref-credential-surface)
- [配置参考](/gateway/configuration-reference)
