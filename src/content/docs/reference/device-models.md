---
title: 设备型号数据库
---
macOS 配套应用通过将 Apple 型号标识符（例如 `iPad16,6`、`Mac16,6`）映射为人类可读的名称，在**实例** UI 中显示友好的 Apple 设备型号名称。

该映射以 JSON 形式内置于：

- `apps/macos/Sources/OpenClaw/Resources/DeviceModels/`

## 数据来源

我们目前内置的映射来自 MIT 许可的仓库：

- `kyle-seongwoo-jun/apple-device-identifiers`

为保持构建的确定性，JSON 文件固定到特定的上游提交（记录在 `apps/macos/Sources/OpenClaw/Resources/DeviceModels/NOTICE.md` 中）。

## 更新数据库

1. 选择要固定的上游提交（iOS 和 macOS 各一个）。
2. 更新 `apps/macos/Sources/OpenClaw/Resources/DeviceModels/NOTICE.md` 中的提交哈希。
3. 重新下载固定到这些提交的 JSON 文件：

```bash
IOS_COMMIT="<commit sha for ios-device-identifiers.json>"
MAC_COMMIT="<commit sha for mac-device-identifiers.json>"

curl -fsSL "https://raw.githubusercontent.com/kyle-seongwoo-jun/apple-device-identifiers/${IOS_COMMIT}/ios-device-identifiers.json" \
  -o apps/macos/Sources/OpenClaw/Resources/DeviceModels/ios-device-identifiers.json

curl -fsSL "https://raw.githubusercontent.com/kyle-seongwoo-jun/apple-device-identifiers/${MAC_COMMIT}/mac-device-identifiers.json" \
  -o apps/macos/Sources/OpenClaw/Resources/DeviceModels/mac-device-identifiers.json
```

4. 确保 `apps/macos/Sources/OpenClaw/Resources/DeviceModels/LICENSE.apple-device-identifiers.txt` 仍与上游一致（如果上游许可证发生变更，请替换该文件）。
5. 验证 macOS 应用能够正常构建（无警告）：

```bash
swift build --package-path apps/macos
```
