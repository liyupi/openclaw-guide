---
title: CI Pipeline
description: OpenClaw CI 流水线的工作原理
summary: "CI 任务图、范围门控和本地等效命令"
read_when:
  - 需要了解某个 CI 任务为何运行或未运行
  - 正在调试失败的 GitHub Actions 检查
---

# CI 流水线

CI 在每次推送到 `main` 和每个 Pull Request 时运行。它使用智能范围划分，在仅文档或原生代码发生变更时跳过昂贵的任务。

## 任务概览

| 任务               | 用途                                                 | 运行时机                                      |
| ----------------- | ------------------------------------------------------- | ------------------------------------------------- |
| `docs-scope`      | 检测仅文档变更                                | 始终运行                                            |
| `changed-scope`   | 检测哪些区域发生变更（node/macos/android/windows） | 非文档 PR                                      |
| `check`           | TypeScript 类型检查、lint、格式化                          | 推送到 `main`，或包含 Node 相关变更的 PR |
| `check-docs`      | Markdown lint + 断链检查                       | 文档发生变更                                            |
| `code-analysis`   | LOC 阈值检查（1000 行）                        | 仅 PR                                          |
| `secrets`         | 检测泄露的密钥                                   | 始终运行                                            |
| `build-artifacts` | 构建一次 dist，与其他任务共享                  | 非文档且 node 发生变更                            |
| `release-check`   | 验证 npm pack 内容                              | 构建之后                                       |
| `checks`          | Node/Bun 测试 + 协议检查                         | 非文档且 node 发生变更                            |
| `checks-windows`  | Windows 特定测试                                  | 非文档且 windows 相关变更                |
| `macos`           | Swift lint/构建/测试 + TS 测试                        | 包含 macos 变更的 PR                            |
| `android`         | Gradle 构建 + 测试                                    | 非文档且 android 发生变更                         |

## 快速失败顺序

任务按顺序排列，使廉价检查在昂贵检查运行前先失败：

1. `docs-scope` + `code-analysis` + `check`（并行，约 1-2 分钟）
2. `build-artifacts`（依赖上述任务）
3. `checks`、`checks-windows`、`macos`、`android`（依赖构建）

范围逻辑位于 `scripts/ci-changed-scope.mjs`，单元测试在 `src/scripts/ci-changed-scope.test.ts` 中。

## 运行器

| 运行器                           | 任务                                       |
| -------------------------------- | ------------------------------------------ |
| `blacksmith-16vcpu-ubuntu-2404`  | 大多数 Linux 任务，包括范围检测 |
| `blacksmith-32vcpu-windows-2025` | `checks-windows`                           |
| `macos-latest`                   | `macos`、`ios`                             |

## 本地等效命令

```bash
pnpm check          # types + lint + format
pnpm test           # vitest tests
pnpm check:docs     # docs format + lint + broken links
pnpm release:check  # validate npm pack
```
