#!/usr/bin/env bash
#
# OpenClaw 一键安装脚本 (macOS / Linux)
# 用法:
#   bash install-openclaw.sh [--version <版本号>]
#   curl -fsSL https://raw.githubusercontent.com/OpenClaw/install/main/install.sh | bash -s -- --version 1.2.3
#

set -euo pipefail

# ── 颜色输出 ──

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${BLUE}ℹ ${NC}$*"; }
success() { echo -e "${GREEN}✅ ${NC}$*"; }
warn()    { echo -e "${YELLOW}⚠️  ${NC}$*"; }
error()   { echo -e "${RED}❌ ${NC}$*"; }
step()    { echo -e "\n${CYAN}━━━ $* ━━━${NC}\n"; }

# ── 交互式输入支持（兼容 curl | bash 管道执行）──

HAS_TTY=false
if [[ -t 0 ]]; then
  HAS_TTY=true
elif [[ -e /dev/tty ]]; then
  HAS_TTY=true
fi

prompt_read() {
  local var_name="$1"
  local prompt_text="$2"
  local default_val="${3:-}"
  if [[ "$HAS_TTY" == "true" ]]; then
    if [[ -t 0 ]]; then
      read -rp "$prompt_text" "$var_name"
    else
      read -rp "$prompt_text" "$var_name" < /dev/tty
    fi
  else
    warn "非交互模式，无法读取用户输入"
    printf -v "$var_name" '%s' "$default_val"
  fi
}

# ── 全局变量 ──

OPENCLAW_VERSION="${OPENCLAW_VERSION:-}"
REQUIRED_NODE_MAJOR=22
NODE_BIN_DIR=""
ARCH=$(uname -m)
case "$ARCH" in
  arm64|aarch64) ARCH="arm64" ;;
  *)             ARCH="x64" ;;
esac
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

# ── PATH 扩展 ──

ensure_path() {
  local dirs=(/opt/homebrew/bin /usr/local/bin)

  for prefix in /opt/homebrew /usr/local; do
    for formula in node@22 node; do
      local bin_dir="$prefix/opt/$formula/bin"
      [[ -x "$bin_dir/node" ]] && dirs+=("$bin_dir") || true
    done
  done

  local nvm_dir="${NVM_DIR:-$HOME/.nvm}"
  if [[ -s "$nvm_dir/nvm.sh" ]]; then
    local nvm_node_dir
    nvm_node_dir=$(bash -c "export NVM_DIR=\"$nvm_dir\" && . \"\$NVM_DIR/nvm.sh\" && dirname \"\$(nvm which default 2>/dev/null)\" 2>/dev/null" < /dev/null 2>/dev/null || true)
    [[ -n "$nvm_node_dir" && "$nvm_node_dir" != *"N/A"* ]] && dirs+=("$nvm_node_dir") || true
  fi

  for d in "${dirs[@]}"; do
    [[ -d "$d" ]] && [[ ":$PATH:" != *":$d:"* ]] && export PATH="$d:$PATH" || true
  done
}

# ── Node.js 版本检测 ──

check_node_version() {
  local cmd="${1:-node}"
  local ver
  ver=$("$cmd" -v 2>/dev/null || true)
  if [[ "$ver" =~ v([0-9]+) ]]; then
    local major="${BASH_REMATCH[1]}"
    if (( major >= REQUIRED_NODE_MAJOR )); then
      echo "$ver"
      return 0
    fi
  fi
  return 1
}

pin_node_path() {
  IFS=':' read -ra path_dirs <<< "$PATH"
  for dir in "${path_dirs[@]}"; do
    if [[ -x "$dir/node" ]]; then
      local ver
      ver=$("$dir/node" -v 2>/dev/null || true)
      if [[ "$ver" =~ v([0-9]+) ]] && (( BASH_REMATCH[1] >= REQUIRED_NODE_MAJOR )); then
        NODE_BIN_DIR="$dir"
        local rest
        rest=$(echo "$PATH" | sed "s|$dir:||g; s|:$dir||g; s|$dir||g")
        export PATH="$dir:$rest"
        info "锁定 Node.js v22 路径: $dir"
        return
      fi
    fi
  done
}

# ── Shell 配置文件写入 ──

get_shell_profiles() {
  local profiles=()
  local login_shell="${SHELL:-}"
  if [[ -z "$login_shell" && "$OS" == "darwin" ]]; then
    login_shell=$(dscl . -read "/Users/$(whoami)" UserShell 2>/dev/null | awk '{print $2}' || true)
  fi

  if [[ "$login_shell" == *zsh* ]]; then
    profiles+=("$HOME/.zshrc")
  elif [[ "$login_shell" == *bash* ]]; then
    profiles+=("$HOME/.bash_profile" "$HOME/.bashrc")
  fi

  [[ "$OS" == "darwin" ]] && [[ ! " ${profiles[*]:-} " =~ ".zshrc" ]] && profiles+=("$HOME/.zshrc") || true
  [[ ! " ${profiles[*]:-} " =~ ".bash_profile" ]] && [[ ! " ${profiles[*]:-} " =~ ".bashrc" ]] && profiles+=("$HOME/.bash_profile") || true

  echo "${profiles[@]}"
}

persist_path_entry() {
  local bin_dir="$1"
  local line="export PATH=\"$bin_dir:\$PATH\""
  local profiles
  read -ra profiles <<< "$(get_shell_profiles)"
  local written=false

  for profile in "${profiles[@]}"; do
    if [[ -f "$profile" ]] && grep -qF "$bin_dir" "$profile" 2>/dev/null; then
      written=true
      continue
    fi
    printf '\n# Added by OpenClaw installer\n%s\n' "$line" >> "$profile"
    info "已将 $bin_dir 添加到 $profile"
    written=true
  done

  if [[ "$written" == "false" ]]; then
    warn "请手动将以下内容添加到 shell 配置文件:"
    echo "  $line"
  fi
}

# ── 下载工具 ──

download_file() {
  local dest="$1"
  shift
  for url in "$@"; do
    local host
    host=$(echo "$url" | sed 's|https\?://\([^/]*\).*|\1|')
    info "正在从 $host 下载..."
    if curl -fsSL --connect-timeout 30 --retry 3 --retry-delay 2 --max-time 300 -o "$dest" "$url" 2>/dev/null; then
      success "下载完成"
      return 0
    fi
    warn "从 $host 下载失败，尝试备用源..."
  done
  return 1
}

get_latest_node_version() {
  local major="$1"
  local urls=(
    "https://npmmirror.com/mirrors/node/latest-v${major}.x/SHASUMS256.txt"
    "https://nodejs.org/dist/latest-v${major}.x/SHASUMS256.txt"
  )
  for url in "${urls[@]}"; do
    local content
    content=$(curl -sL --connect-timeout 10 "$url" 2>/dev/null || true)
    local ver
    ver=$(echo "$content" | grep -oE 'node-(v[0-9]+\.[0-9]+\.[0-9]+)' | head -1 | sed 's/node-//')
    if [[ -n "$ver" ]]; then
      echo "$ver"
      return 0
    fi
  done
  return 1
}

# ── 安装 Node.js ──

install_node_via_nvm() {
  local nvm_dir="${NVM_DIR:-$HOME/.nvm}"
  [[ ! -s "$nvm_dir/nvm.sh" ]] && return 1

  info "检测到 nvm，正在使用 nvm 安装 Node.js v22..."

  # nvm.sh 有大量副作用（trap、set -e 干扰等），必须在独立子进程中运行
  if ! NVM_DIR="$nvm_dir" NVM_NODEJS_ORG_MIRROR="https://npmmirror.com/mirrors/node" \
    bash -c '. "$NVM_DIR/nvm.sh" && nvm install 22 && nvm alias default 22' < /dev/null; then
    warn "nvm 安装 Node.js 失败"
    return 1
  fi

  # 安装完成后，通过子进程查询 node 路径（不在父 shell 中 source nvm.sh）
  local node_bin_dir
  node_bin_dir=$(NVM_DIR="$nvm_dir" bash -c \
    '. "$NVM_DIR/nvm.sh" && dirname "$(nvm which default)"' < /dev/null 2>/dev/null) || true

  if [[ -n "$node_bin_dir" && -x "$node_bin_dir/node" ]]; then
    export PATH="$node_bin_dir:$PATH"
    local ver
    ver=$(check_node_version "$node_bin_dir/node") && {
      success "Node.js $ver 已通过 nvm 安装并设为默认版本"
      ensure_nvm_in_profile
      return 0
    }
  fi

  warn "nvm 安装 Node.js 失败"
  return 1
}

ensure_nvm_in_profile() {
  local nvm_dir="${NVM_DIR:-$HOME/.nvm}"
  local profiles
  read -ra profiles <<< "$(get_shell_profiles)"
  local block
  block=$(printf '\n# nvm (added by OpenClaw installer)\nexport NVM_DIR="%s"\n[ -s "$NVM_DIR/nvm.sh" ] && \\. "$NVM_DIR/nvm.sh"\n' "$nvm_dir")

  for profile in "${profiles[@]}"; do
    if [[ -f "$profile" ]] && grep -q 'NVM_DIR' "$profile" && grep -q 'nvm.sh' "$profile"; then
      continue
    fi
    echo "$block" >> "$profile"
    info "已将 nvm 初始化脚本添加到 $profile"
  done
}

install_node_via_brew() {
  [[ "$OS" != "darwin" ]] && return 1

  local brew_path=""
  for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [[ -x "$p" ]] && brew_path="$p" && break
  done
  [[ -z "$brew_path" ]] && return 1

  info "检测到 Homebrew，正在使用 brew 安装 Node.js v22..."
  export HOMEBREW_NO_AUTO_UPDATE=1
  export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"
  export HOMEBREW_API_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles/api"

  if "$brew_path" install node@22; then
    "$brew_path" link --force --overwrite node@22 2>/dev/null || warn "brew link 未成功，将使用 PATH 方式配置"

    local prefix
    prefix=$("$brew_path" --prefix node@22 2>/dev/null || true)
    if [[ -n "$prefix" ]]; then
      export PATH="$prefix/bin:$PATH"
      persist_path_entry "$prefix/bin"
    fi

    local ver
    ver=$(check_node_version) && {
      success "Node.js $ver 已通过 Homebrew 安装成功"
      return 0
    }
  fi
  warn "Homebrew 安装 Node.js 失败"
  return 1
}

install_node_direct() {
  info "正在直接下载安装 Node.js v22..."

  local version
  version=$(get_latest_node_version 22) || {
    error "无法获取 Node.js 版本信息，请检查网络连接"
    return 1
  }
  info "最新 LTS 版本: $version"

  local os_name
  [[ "$OS" == "darwin" ]] && os_name="darwin" || os_name="linux"
  local filename="node-${version}-${os_name}-${ARCH}.tar.gz"
  local tmp_path
  tmp_path=$(mktemp -d)
  local tmp_file="$tmp_path/$filename"

  if ! download_file "$tmp_file" \
    "https://npmmirror.com/mirrors/node/${version}/${filename}" \
    "https://nodejs.org/dist/${version}/${filename}"; then
    error "Node.js 下载失败，请检查网络连接"
    rm -rf "$tmp_path"
    return 1
  fi

  local installed=false

  # 尝试安装到 /usr/local
  if tar -xzf "$tmp_file" -C /usr/local --strip-components=1 2>/dev/null; then
    installed=true
    success "Node.js 已安装到 /usr/local"
    persist_path_entry "/usr/local/bin"
  else
    info "权限不足，正在请求管理员权限..."
    if [[ "$OS" == "darwin" ]]; then
      if osascript -e "do shell script \"tar -xzf '$tmp_file' -C /usr/local --strip-components=1\" with administrator privileges" 2>/dev/null; then
        installed=true
        success "Node.js 已安装到 /usr/local"
        persist_path_entry "/usr/local/bin"
      fi
    else
      if sudo tar -xzf "$tmp_file" -C /usr/local --strip-components=1 2>/dev/null; then
        installed=true
        success "Node.js 已安装到 /usr/local"
        persist_path_entry "/usr/local/bin"
      fi
    fi
  fi

  # 回退到用户目录
  if [[ "$installed" == "false" ]]; then
    local user_dir="$HOME/.local/node"
    info "正在安装到用户目录 $user_dir..."
    mkdir -p "$user_dir"
    if tar -xzf "$tmp_file" -C "$user_dir" --strip-components=1; then
      export PATH="$user_dir/bin:$PATH"
      persist_path_entry "$user_dir/bin"
      installed=true
      success "Node.js 已安装到 $user_dir"
    fi
  fi

  rm -rf "$tmp_path"

  [[ "$installed" == "false" ]] && return 1

  local ver
  ver=$(check_node_version) && {
    success "Node.js $ver 已可用"
    return 0
  }
  warn "Node.js 安装完成但验证失败"
  return 1
}

# ── 安装 Git ──

check_git_version() {
  if [[ "$OS" == "darwin" ]]; then
    for cmd in /opt/homebrew/bin/git /usr/local/bin/git; do
      if [[ -x "$cmd" ]]; then
        "$cmd" --version 2>/dev/null && return 0
      fi
    done
    xcode-select -p &>/dev/null || return 1
  fi
  git --version 2>/dev/null
}

install_git_mac() {
  local brew_path=""
  for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [[ -x "$p" ]] && brew_path="$p" && break
  done

  if [[ -n "$brew_path" ]]; then
    info "检测到 Homebrew，正在使用 brew 安装 Git..."
    export HOMEBREW_NO_AUTO_UPDATE=1
    export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"
    export HOMEBREW_API_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles/api"
    if "$brew_path" install git; then
      check_git_version &>/dev/null && { success "Git 已通过 Homebrew 安装"; return 0; }
    fi
    warn "Homebrew 安装 Git 失败"
  fi

  info "正在通过 Xcode Command Line Tools 安装 Git..."
  info "（首次安装 CLT 可能需要几分钟，请耐心等待）"
  touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress 2>/dev/null || true
  local label
  label=$(softwareupdate -l 2>/dev/null | grep -o 'Label: Command Line Tools.*' | head -1 | sed 's/Label: //' || true)

  if [[ -n "$label" ]]; then
    info "找到: $label"
    info "正在安装，这可能需要几分钟..."
    if ! softwareupdate -i "$label" 2>/dev/null; then
      info "需要管理员权限..."
      osascript -e "do shell script \"softwareupdate -i '$label'\" with administrator privileges" 2>/dev/null || true
    fi
    rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress 2>/dev/null || true
    check_git_version &>/dev/null && { success "Git 已通过 Xcode CLT 安装"; return 0; }
  fi

  rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress 2>/dev/null || true
  return 1
}

install_git_linux() {
  info "正在安装 Git..."
  local -A managers=(
    [apt-get]="install -y git"
    [dnf]="install -y git"
    [yum]="install -y git"
    [pacman]="-S --noconfirm git"
    [apk]="add git"
    [zypper]="install -y git"
  )

  for cmd in apt-get dnf yum pacman apk zypper; do
    if command -v "$cmd" &>/dev/null; then
      info "检测到 ${cmd}，正在安装..."
      # shellcheck disable=SC2086
      if $cmd ${managers[$cmd]} 2>/dev/null || sudo $cmd ${managers[$cmd]} 2>/dev/null; then
        check_git_version &>/dev/null && { success "Git 安装成功"; return 0; }
      fi
    fi
  done
  return 1
}

# ── npm 全局安装（带权限回退） ──

npm_install_global() {
  local pkg="$1"
  local npm_cmd="${NODE_BIN_DIR:+$NODE_BIN_DIR/}npm"

  if "$npm_cmd" install -g "$pkg" --loglevel=notice; then
    return 0
  fi

  info "权限不足，正在请求管理员权限..."
  if [[ "$OS" == "darwin" ]]; then
    osascript -e "do shell script \"'$npm_cmd' install -g $pkg --loglevel=notice\" with administrator privileges" 2>/dev/null && return 0
  else
    sudo "$npm_cmd" install -g "$pkg" --loglevel=notice && return 0
  fi

  info "正在使用用户目录安装..."
  local npm_global_dir="$HOME/.npm-global"
  mkdir -p "$npm_global_dir"
  "$npm_cmd" config set prefix "$npm_global_dir"
  export PATH="$npm_global_dir/bin:$PATH"
  persist_path_entry "$npm_global_dir/bin"
  "$npm_cmd" install -g "$pkg" --loglevel=notice
}

persist_npm_global_bin() {
  local npm_cmd="${NODE_BIN_DIR:+$NODE_BIN_DIR/}npm"
  local prefix
  prefix=$("$npm_cmd" prefix -g 2>/dev/null || true)
  if [[ -n "$prefix" ]]; then
    local bin_dir="$prefix/bin"
    [[ -d "$bin_dir" ]] && persist_path_entry "$bin_dir" || true
  fi
}

# ── 主流程步骤 ──

step_check_node() {
  step "步骤 1/6: 准备 Node.js 环境"
  ensure_path

  local ver
  if ver=$(check_node_version); then
    success "Node.js $ver 已安装，版本满足要求 (>= 22)"
    pin_node_path
    return 0
  fi

  local existing_ver
  existing_ver=$(node -v 2>/dev/null || true)
  if [[ -n "$existing_ver" ]]; then
    warn "检测到 Node.js ${existing_ver}，版本过低，需要 v22 以上"
  else
    warn "未检测到 Node.js"
  fi

  info "正在自动安装 Node.js v22..."

  install_node_via_nvm && { pin_node_path; return 0; }
  install_node_via_brew && { pin_node_path; return 0; }
  install_node_direct && { pin_node_path; return 0; }

  error "所有安装方式均失败，请检查网络连接后重试"
  return 1
}

step_check_git() {
  step "步骤 2/6: 准备 Git 环境"

  if check_git_version &>/dev/null; then
    success "$(git --version 2>/dev/null || echo 'Git') 已安装"
    return 0
  fi

  warn "未检测到 Git，正在自动安装..."

  if [[ "$OS" == "darwin" ]]; then
    install_git_mac && return 0
  else
    install_git_linux && return 0
  fi

  error "Git 自动安装失败，请手动安装 Git 后重试"
  echo "  下载地址: https://git-scm.com/downloads"
  return 1
}

step_set_mirror() {
  step "步骤 3/6: 设置国内 npm 镜像"
  local npm_cmd="${NODE_BIN_DIR:+$NODE_BIN_DIR/}npm"
  if "$npm_cmd" config set registry https://registry.npmmirror.com; then
    success "npm 镜像已设置为 https://registry.npmmirror.com"
    return 0
  fi
  error "设置 npm 镜像失败"
  return 1
}

_progress_bar() {
  local done_file=$1
  local progress=0
  local width=30
  while [[ ! -f "$done_file" ]]; do
    if (( progress < 30 )); then
      (( progress += 3 ))
    elif (( progress < 60 )); then
      (( progress += 2 ))
    elif (( progress < 90 )); then
      (( progress += 1 ))
    fi
    if (( progress > 90 )); then progress=90; fi
    local filled=$(( progress * width / 100 ))
    local empty=$(( width - filled ))
    local bar="" i
    for (( i = 0; i < filled; i++ )); do bar+="█"; done
    for (( i = 0; i < empty; i++ )); do bar+="░"; done
    printf "\r  安装进度 [%s] %3d%%" "$bar" "$progress"
    sleep 1
  done
}

step_install_openclaw() {
  step "步骤 4/6: 安装 OpenClaw"
  if [[ -n "$OPENCLAW_VERSION" ]]; then
    info "正在安装 OpenClaw v${OPENCLAW_VERSION}，请耐心等待..."
  else
    info "正在安装 OpenClaw 最新版，请耐心等待..."
  fi

  local log_file done_file
  log_file=$(mktemp)
  done_file=$(mktemp)
  rm -f "$done_file"

  (
    set +e
    local pkg_spec="openclaw@${OPENCLAW_VERSION:-latest}"
    npm_install_global "$pkg_spec" > "$log_file" 2>&1
    echo $? > "$done_file"
  ) &

  _progress_bar "$done_file"

  wait 2>/dev/null || true
  local exit_code
  exit_code=$(cat "$done_file")

  local bar="" i
  for (( i = 0; i < 30; i++ )); do bar+="█"; done

  if [[ "$exit_code" == "0" ]]; then
    printf "\r  安装进度 [%s] 100%%\n" "$bar"
    persist_npm_global_bin
    success "OpenClaw 安装完成"
    rm -f "$log_file" "$done_file"
    return 0
  fi

  printf "\r  安装进度 [%s] 失败\n" "$bar"
  error "OpenClaw 安装失败"
  rm -f "$log_file" "$done_file"
  return 1
}

step_verify() {
  step "步骤 5/6: 验证安装结果"
  ensure_path

  local openclaw_cmd="${NODE_BIN_DIR:+$NODE_BIN_DIR/}openclaw"
  local ver
  ver=$("$openclaw_cmd" -v 2>/dev/null || openclaw -v 2>/dev/null || true)

  if [[ -n "$ver" ]]; then
    success "OpenClaw $ver 安装成功！"
    echo -e "\n${GREEN}🦞 恭喜！你的龙虾已就位！${NC}\n"
    return 0
  fi

  warn "未能验证 OpenClaw 安装，请尝试重新打开终端后执行 openclaw -v"
  return 0
}

step_onboard() {
  step "步骤 6/6: 配置 OpenClaw"

  echo -e "${CYAN}请选择 AI 厂商:${NC}"
  echo ""
  echo "  1) openai         - OpenAI (GPT-5.1 Codex, o3, o4-mini 等)"
  echo "  2) anthropic      - Anthropic (Claude Sonnet 4.5, Opus 4.6)"
  echo "  3) gemini         - Google Gemini (2.5 Pro, 2.5 Flash)"
  echo "  4) mistral        - Mistral (Large, Codestral)"
  echo "  5) zai            - 智谱 AI (GLM-5, GLM-4.7)"
  echo "  6) moonshot       - Moonshot (Kimi K2.5)"
  echo "  7) kimi-coding    - Kimi Coding (K2.5)"
  echo "  8) qianfan        - 百度千帆 (ERNIE 4.5, DeepSeek R1)"
  echo "  9) xiaomi         - 小米 (MiMo V2 Flash)"
  echo " 10) custom         - 自定义 (OpenAI/Anthropic 兼容接口)"
  echo "  0) 跳过配置"
  echo ""

  local choice
  prompt_read choice "请输入编号 [0-10]: "

  if [[ "$choice" == "0" ]]; then
    info "已跳过配置"
    info "重新执行本安装脚本或运行 openclaw onboard 即可进入配置"
    return 0
  fi

  local provider auth_choice key_flag
  case "$choice" in
    1)  provider="openai";      auth_choice="openai-api-key";     key_flag="--openai-api-key" ;;
    2)  provider="anthropic";   auth_choice="apiKey";              key_flag="--anthropic-api-key" ;;
    3)  provider="gemini";      auth_choice="gemini-api-key";      key_flag="--gemini-api-key" ;;
    4)  provider="mistral";     auth_choice="mistral-api-key";     key_flag="--mistral-api-key" ;;
    5)  provider="zai";         auth_choice="zai-api-key";         key_flag="--zai-api-key" ;;
    6)  provider="moonshot";    auth_choice="moonshot-api-key";    key_flag="--moonshot-api-key" ;;
    7)  provider="kimi-coding"; auth_choice="kimi-code-api-key";   key_flag="--kimi-code-api-key" ;;
    8)  provider="qianfan";     auth_choice="qianfan-api-key";     key_flag="--qianfan-api-key" ;;
    9)  provider="xiaomi";      auth_choice="xiaomi-api-key";      key_flag="--xiaomi-api-key" ;;
    10) provider="custom";      auth_choice="custom-api-key";      key_flag="--custom-api-key" ;;
    *)  warn "无效选择，跳过配置"; return 0 ;;
  esac

  echo ""
  local api_key
  prompt_read api_key "请输入 API Key: "
  if [[ -z "$api_key" ]]; then
    error "API Key 不能为空"
    return 1
  fi

  local openclaw_cmd="${NODE_BIN_DIR:+$NODE_BIN_DIR/}openclaw"
  command -v "$openclaw_cmd" &>/dev/null || openclaw_cmd="openclaw"

  local onboard_args=(
    onboard --non-interactive
    --accept-risk
    --mode local
    --auth-choice "$auth_choice"
    "$key_flag" "$api_key"
    --secret-input-mode plaintext
    --gateway-port 18789
    --gateway-bind loopback
    --install-daemon
    --daemon-runtime node
    --skip-skills
  )

  if [[ "$provider" == "custom" ]]; then
    echo ""
    local custom_base_url custom_model_id
    prompt_read custom_base_url "请输入自定义 Base URL: "
    prompt_read custom_model_id "请输入自定义 Model ID: "

    [[ -n "$custom_base_url" ]] && onboard_args+=("--custom-base-url" "$custom_base_url") || true
    [[ -n "$custom_model_id" ]] && onboard_args+=("--custom-model-id" "$custom_model_id") || true
    onboard_args+=("--custom-compatibility" "openai")
  fi

  info "正在配置 OpenClaw..."
  if "$openclaw_cmd" "${onboard_args[@]}"; then
    success "OpenClaw 配置完成！"
  else
    error "配置失败，请检查 API Key 是否正确"
    return 1
  fi

  # 选择默认模型
  if [[ "$provider" != "custom" ]]; then
    echo ""
    echo -e "${CYAN}请选择默认模型:${NC}"
    echo ""

    local -a model_ids model_labels
    case "$provider" in
      openai)
        model_ids=("openai/gpt-5.1-codex" "openai/o3" "openai/o4-mini" "openai/gpt-4.1")
        model_labels=("GPT-5.1 Codex" "o3" "o4-mini" "GPT-4.1") ;;
      anthropic)
        model_ids=("anthropic/claude-sonnet-4-5" "anthropic/claude-opus-4-6")
        model_labels=("Claude Sonnet 4.5" "Claude Opus 4.6") ;;
      gemini)
        model_ids=("gemini/gemini-2.5-pro" "gemini/gemini-2.5-flash")
        model_labels=("Gemini 2.5 Pro" "Gemini 2.5 Flash") ;;
      mistral)
        model_ids=("mistral/mistral-large-latest" "mistral/codestral-latest")
        model_labels=("Mistral Large" "Codestral") ;;
      zai)
        model_ids=("zai/glm-5" "zai/glm-4.7")
        model_labels=("GLM-5" "GLM-4.7") ;;
      moonshot)
        model_ids=("moonshot/kimi-k2.5" "moonshot/kimi-k2-thinking" "moonshot/kimi-k2-thinking-turbo")
        model_labels=("Kimi K2.5" "Kimi K2 Thinking" "Kimi K2 Thinking Turbo") ;;
      kimi-coding)
        model_ids=("kimi-coding/k2p5")
        model_labels=("Kimi K2.5 (Coding)") ;;
      qianfan)
        model_ids=("qianfan/ernie-4.5-turbo-vl-32k" "qianfan/deepseek-r1")
        model_labels=("ERNIE 4.5 Turbo" "DeepSeek R1") ;;
      xiaomi)
        model_ids=("xiaomi/mimo-v2-flash")
        model_labels=("MiMo V2 Flash") ;;
    esac

    local i
    for i in "${!model_labels[@]}"; do
      echo "  $((i+1))) ${model_labels[$i]}"
    done
    echo "  0) 跳过"
    echo ""
    local model_choice
    prompt_read model_choice "请选择 [0-${#model_labels[@]}]: "

    if [[ "$model_choice" != "0" && -n "$model_choice" ]]; then
      local idx=$((model_choice - 1))
      if [[ $idx -ge 0 && $idx -lt ${#model_ids[@]} ]]; then
        info "正在设置默认模型: ${model_ids[$idx]}"
        "$openclaw_cmd" models set "${model_ids[$idx]}" 2>/dev/null && \
          success "默认模型已设置为 ${model_labels[$idx]}" || \
          warn "模型设置未成功，可稍后通过 openclaw models set 手动设置"
      fi
    fi
  fi

  # 启动控制面板
  echo ""
  info "正在打开 OpenClaw 控制面板..."
  nohup "$openclaw_cmd" dashboard &>/dev/null &
  success "已在后台启动，请访问 http://127.0.0.1:18789"
}

# ── 主函数 ──

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version|-v)
        if [[ -z "${2:-}" ]]; then
          error "--version 需要指定版本号，例如: --version 1.2.3"
          exit 1
        fi
        OPENCLAW_VERSION="$2"
        shift 2
        ;;
      --help|-h)
        echo "用法: bash install-openclaw.sh [选项]"
        echo ""
        echo "选项:"
        echo "  --version, -v <版本号>  安装指定版本的 OpenClaw (例如: 1.2.3)"
        echo "  --help, -h              显示帮助信息"
        echo ""
        echo "示例:"
        echo "  bash install-openclaw.sh                    # 安装最新版"
        echo "  bash install-openclaw.sh --version 1.2.3    # 安装指定版本"
        echo "  OPENCLAW_VERSION=1.2.3 bash install-openclaw.sh  # 通过环境变量指定"
        exit 0
        ;;
      *)
        warn "未知参数: $1"
        shift
        ;;
    esac
  done
}

main() {
  parse_args "$@"

  echo ""
  echo -e "${GREEN}🦞 OpenClaw 一键安装脚本${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  # 检测是否已安装
  ensure_path
  local existing_ver
  existing_ver=$(openclaw -v 2>/dev/null || true)
  if [[ -n "$existing_ver" && -z "$OPENCLAW_VERSION" ]]; then
    success "OpenClaw $existing_ver 已安装，无需重复安装"
    echo -e "\n${GREEN}🦞 你的龙虾已就位！${NC}\n"
    echo ""
    local reconfig
    prompt_read reconfig "是否要重新配置 OpenClaw? [y/N]: "
    if [[ "$reconfig" =~ ^[Yy] ]]; then
      step_onboard
    fi
    return 0
  fi

  step_check_node || exit 1
  step_check_git || exit 1
  step_set_mirror || exit 1
  step_install_openclaw || exit 1
  step_verify || exit 1
  step_onboard

  echo ""
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}🦞 安装完成！请打开新终端窗口开始使用 OpenClaw${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  if [[ -n "${TERM_PROGRAM:-}" && "$HAS_TTY" == "true" ]]; then
    echo "按回车键关闭窗口..."
    if [[ -t 0 ]]; then
      read -r
    else
      read -r < /dev/tty 2>/dev/null || true
    fi
  fi
}

main "$@"
