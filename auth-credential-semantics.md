# 认证凭据语义

本文档定义了以下组件使用的规范凭据资格和解析语义：

- `resolveAuthProfileOrder`
- `resolveApiKeyForProfile`
- `models status --probe`
- `doctor-auth`

目标是保持选择时和运行时的行为一致。

## 稳定的原因代码

- `ok`
- `missing_credential`
- `invalid_expires`
- `expired`
- `unresolved_ref`

## 令牌凭据

令牌凭据（`type: "token"`）支持内联 `token` 和/或 `tokenRef`。

### 资格规则

1. 当 `token` 和 `tokenRef` 都不存在时，令牌配置不合格。
2. `expires` 是可选的。
3. 如果存在 `expires`，它必须是大于 `0` 的有限数字。
4. 如果 `expires` 无效（`NaN`、`0`、负数、非有限或类型错误），配置以 `invalid_expires` 标记为不合格。
5. 如果 `expires` 已过期，配置以 `expired` 标记为不合格。
6. `tokenRef` 不会绕过 `expires` 验证。

### 解析规则

1. 解析器对 `expires` 的语义与资格语义一致。
2. 对于合格的配置，令牌材料可以从内联值或 `tokenRef` 解析。
3. 无法解析的 ref 在 `models status --probe` 输出中产生 `unresolved_ref`。

## 旧版兼容消息

为了脚本兼容性，探测错误保持以下第一行不变：

`Auth profile credentials are missing or expired.`

人类可读的详细信息和稳定的原因代码可以添加在后续行中。
