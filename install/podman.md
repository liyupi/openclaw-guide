---
summary: "在无根 Podman 容器中运行 OpenClaw"
read_when:
  - 希望使用 Podman 代替 Docker 运行容器化的 Gateway 网关
title: "Podman"
---

# Podman

在**无根** Podman 容器中运行 OpenClaw Gateway 网关。使用与 Docker 相同的镜像（从仓库 [Dockerfile](https://github.com/openclaw/openclaw/blob/main/Dockerfile) 构建）。

## 前提条件

- Podman（无根模式）
- 一次性设置需要 Sudo（创建用户、构建镜像）

## 快速开始

**1. 一次性设置**（从仓库根目录执行；创建用户、构建镜像、安装启动脚本）：

```bash
./setup-podman.sh
```

这还会创建一个最小的 `~openclaw/.openclaw/openclaw.json`（设置 `gateway.mode="local"`），以便 Gateway 网关无需运行向导即可启动。

默认情况下容器**不会**安装为 systemd 服务，你需要手动启动（见下文）。如需生产级的自动启动和重启设置，请改为将其安装为 systemd Quadlet 用户服务：

```bash
./setup-podman.sh --quadlet
```

（或设置 `OPENCLAW_PODMAN_QUADLET=1`；使用 `--container` 仅安装容器和启动脚本。）

可选的构建时环境变量（在运行 `setup-podman.sh` 前设置）：

- `OPENCLAW_DOCKER_APT_PACKAGES` — 在镜像构建期间安装额外的 apt 包
- `OPENCLAW_EXTENSIONS` — 预安装扩展依赖（空格分隔的扩展名称，例如 `diagnostics-otel matrix`）

**2. 启动 Gateway 网关**（手动，用于快速冒烟测试）：

```bash
./scripts/run-openclaw-podman.sh launch
```

**3. 引导向导**（例如添加通道或提供者）：

```bash
./scripts/run-openclaw-podman.sh launch setup
```

然后打开 `http://127.0.0.1:18789/` 并使用 `~openclaw/.openclaw/.env` 中的令牌（或设置时打印的值）。

## Systemd（Quadlet，可选）

如果你运行了 `./setup-podman.sh --quadlet`（或 `OPENCLAW_PODMAN_QUADLET=1`），会安装一个 [Podman Quadlet](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html) 单元，使 Gateway 网关作为 openclaw 用户的 systemd 用户服务运行。设置结束时服务会被启用并启动。

- **启动：** `sudo systemctl --machine openclaw@ --user start openclaw.service`
- **停止：** `sudo systemctl --machine openclaw@ --user stop openclaw.service`
- **状态：** `sudo systemctl --machine openclaw@ --user status openclaw.service`
- **日志：** `sudo journalctl --machine openclaw@ --user -u openclaw.service -f`

Quadlet 文件位于 `~openclaw/.config/containers/systemd/openclaw.container`。要更改端口或环境变量，请编辑该文件（或其引用的 `.env`），然后执行 `sudo systemctl --machine openclaw@ --user daemon-reload` 并重启服务。启动时，如果 openclaw 启用了 lingering，服务会自动启动（设置时如果 loginctl 可用会执行此操作）。

要在初始设置未使用 Quadlet 后添加，请重新运行：`./setup-podman.sh --quadlet`。

## openclaw 用户（非登录）

`setup-podman.sh` 创建一个专用系统用户 `openclaw`：

- **Shell：** `nologin` — 无交互式登录；减少攻击面。
- **主目录：** 例如 `/home/openclaw` — 存放 `~/.openclaw`（配置、工作区）和启动脚本 `run-openclaw-podman.sh`。
- **无根 Podman：** 用户必须拥有 **subuid** 和 **subgid** 范围。许多发行版在创建用户时会自动分配。如果设置时打印警告，请在 `/etc/subuid` 和 `/etc/subgid` 中添加以下行：

  ```text
  openclaw:100000:65536
  ```

  然后以该用户身份启动 Gateway 网关（例如通过 cron 或 systemd）：

  ```bash
  sudo -u openclaw /home/openclaw/run-openclaw-podman.sh
  sudo -u openclaw /home/openclaw/run-openclaw-podman.sh setup
  ```

- **配置：** 只有 `openclaw` 和 root 可以访问 `/home/openclaw/.openclaw`。要编辑配置：Gateway 网关运行后使用控制 UI，或 `sudo -u openclaw $EDITOR /home/openclaw/.openclaw/openclaw.json`。

## 环境与配置

- **令牌：** 存储在 `~openclaw/.openclaw/.env` 中，键为 `OPENCLAW_GATEWAY_TOKEN`。`setup-podman.sh` 和 `run-openclaw-podman.sh` 会在缺失时生成（使用 `openssl`、`python3` 或 `od`）。
- **可选：** 在该 `.env` 中你可以设置提供者密钥（例如 `GROQ_API_KEY`、`OLLAMA_API_KEY`）和其他 OpenClaw 环境变量。
- **主机端口：** 默认脚本映射 `18789`（Gateway 网关）和 `18790`（桥接）。启动时通过 `OPENCLAW_PODMAN_GATEWAY_HOST_PORT` 和 `OPENCLAW_PODMAN_BRIDGE_HOST_PORT` 覆盖**主机**端口映射。
- **Gateway 网关绑定：** 默认情况下，`run-openclaw-podman.sh` 以 `--bind loopback` 启动 Gateway 网关以实现安全的本地访问。要在局域网上暴露，请设置 `OPENCLAW_GATEWAY_BIND=lan` 并在 `openclaw.json` 中配置 `gateway.controlUi.allowedOrigins`（或显式启用 host-header 回退）。
- **路径：** 主机配置和工作区默认为 `~openclaw/.openclaw` 和 `~openclaw/.openclaw/workspace`。通过 `OPENCLAW_CONFIG_DIR` 和 `OPENCLAW_WORKSPACE_DIR` 覆盖启动脚本使用的主机路径。

## 存储模型

- **持久化主机数据：** `OPENCLAW_CONFIG_DIR` 和 `OPENCLAW_WORKSPACE_DIR` 被绑定挂载到容器中，在主机上保留状态。
- **临时沙箱 tmpfs：** 如果你启用了 `agents.defaults.sandbox`，工具沙箱容器会在 `/tmp`、`/var/tmp` 和 `/run` 挂载 `tmpfs`。这些路径由内存支撑，随沙箱容器消失；顶层 Podman 容器设置不会添加自己的 tmpfs 挂载。
- **磁盘增长热点：** 需要关注的主要路径有 `media/`、`agents/<agentId>/sessions/sessions.json`、会话记录 JSONL 文件、`cron/runs/*.jsonl` 以及 `/tmp/openclaw/`（或你配置的 `logging.file`）下的滚动文件日志。

`setup-podman.sh` 现在会在私有临时目录中暂存镜像 tar，并在设置过程中打印选择的基础目录。对于非 root 运行，它仅在该基础目录安全可用时接受 `TMPDIR`；否则回退到 `/var/tmp`，然后是 `/tmp`。保存的 tar 保持仅所有者可访问，并流式传输到目标用户的 `podman load`，因此私有调用者临时目录不会阻塞设置。

## 常用命令

- **日志：** 使用 Quadlet：`sudo journalctl --machine openclaw@ --user -u openclaw.service -f`。使用脚本：`sudo -u openclaw podman logs -f openclaw`
- **停止：** 使用 Quadlet：`sudo systemctl --machine openclaw@ --user stop openclaw.service`。使用脚本：`sudo -u openclaw podman stop openclaw`
- **重新启动：** 使用 Quadlet：`sudo systemctl --machine openclaw@ --user start openclaw.service`。使用脚本：重新运行启动脚本或 `podman start openclaw`
- **移除容器：** `sudo -u openclaw podman rm -f openclaw` — 主机上的配置和工作区会保留

## 故障排查

- **配置或 auth-profiles 权限被拒（EACCES）：** 容器默认使用 `--userns=keep-id`，以与运行脚本的主机用户相同的 uid/gid 运行。确保你的主机 `OPENCLAW_CONFIG_DIR` 和 `OPENCLAW_WORKSPACE_DIR` 由该用户拥有。
- **Gateway 网关启动被阻止（缺少 `gateway.mode=local`）：** 确保 `~openclaw/.openclaw/openclaw.json` 存在并设置了 `gateway.mode="local"`。`setup-podman.sh` 会在缺失时创建该文件。
- **openclaw 用户的无根 Podman 失败：** 检查 `/etc/subuid` 和 `/etc/subgid` 是否包含 `openclaw` 的行（例如 `openclaw:100000:65536`）。如果缺少请添加并重启。
- **容器名称已在使用：** 启动脚本使用 `podman run --replace`，因此再次启动时会替换现有容器。要手动清理：`podman rm -f openclaw`。
- **以 openclaw 身份运行时找不到脚本：** 确保已运行 `setup-podman.sh`，使 `run-openclaw-podman.sh` 被复制到 openclaw 的主目录（例如 `/home/openclaw/run-openclaw-podman.sh`）。
- **Quadlet 服务未找到或启动失败：** 编辑 `.container` 文件后运行 `sudo systemctl --machine openclaw@ --user daemon-reload`。Quadlet 需要 cgroups v2：`podman info --format '{{.Host.CgroupsVersion}}'` 应显示 `2`。

## 可选：以你自己的用户身份运行

要以普通用户身份运行 Gateway 网关（不使用专用 openclaw 用户）：构建镜像，创建 `~/.openclaw/.env` 并设置 `OPENCLAW_GATEWAY_TOKEN`，然后使用 `--userns=keep-id` 并挂载到你的 `~/.openclaw` 来运行容器。启动脚本是为 openclaw 用户流程设计的；对于单用户设置，你可以改为手动运行脚本中的 `podman run` 命令，将配置和工作区指向你的主目录。建议大多数用户使用 `setup-podman.sh` 并以 openclaw 用户运行，以隔离配置和进程。
