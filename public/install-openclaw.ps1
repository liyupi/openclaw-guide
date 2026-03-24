<#
.SYNOPSIS
  OpenClaw 一键安装脚本 (Windows)
.DESCRIPTION
  自动检测并安装 Node.js v22+、Git，然后安装并配置 OpenClaw。
.PARAMETER Version
  指定安装的 OpenClaw 版本号（例如 1.2.3）。不指定则安装最新版。
.NOTES
  用法:
    powershell -ExecutionPolicy Bypass -File install-openclaw.ps1
    powershell -ExecutionPolicy Bypass -File install-openclaw.ps1 -Version 1.2.3
  在线一键安装（推荐，直接在当前窗口执行，安装后立即可用）:
    irm https://你的域名/install-openclaw.ps1 | iex
  指定版本（通过环境变量）:
    $env:OPENCLAW_VERSION='1.2.3'; irm https://你的域名/install-openclaw.ps1 | iex
  如果中文乱码，改用:
    & {$w=New-Object Net.WebClient;$w.Encoding=[Text.Encoding]::UTF8;iex $w.DownloadString('https://你的域名/install-openclaw.ps1')}
#>
param(
    [string]$Version = ""
)

# ── 执行策略自修复：如果当前策略阻止脚本运行，自动以 Bypass 重启 ──
if ($MyInvocation.MyCommand.Path) {
    try {
        $policy = Get-ExecutionPolicy -Scope Process
        if ($policy -eq "Restricted" -or $policy -eq "AllSigned") {
            Write-Host "  [INFO] 检测到执行策略为 $policy，正在以 Bypass 策略重新启动..." -ForegroundColor Blue
            Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"" -Wait -NoNewWindow
            exit $LASTEXITCODE
        }
    } catch {}
}

# ── 强制 UTF-8 编码（解决中文乱码）──
# 注意：不使用 chcp 65001，它会导致旧版控制台 CJK 字符重复显示
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "  [FAIL] 需要 PowerShell 5.0 或更高版本，当前版本: $($PSVersionTable.PSVersion)" -ForegroundColor Red
    exit 1
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ── 颜色输出 ──

function Write-Info    { param($Msg) Write-Host "  [INFO] " -ForegroundColor Blue -NoNewline; Write-Host $Msg }
function Write-Ok      { param($Msg) Write-Host "  [OK]   " -ForegroundColor Green -NoNewline; Write-Host $Msg }
function Write-Warn    { param($Msg) Write-Host "  [WARN] " -ForegroundColor Yellow -NoNewline; Write-Host $Msg }
function Write-Err     { param($Msg) Write-Host "  [FAIL] " -ForegroundColor Red -NoNewline; Write-Host $Msg }
function Write-Step    { param($Msg) Write-Host "`n━━━ $Msg ━━━`n" -ForegroundColor Cyan }

# ── 全局变量 ──

$script:OpenClawVersion = if ($Version) { $Version } elseif ($env:OPENCLAW_VERSION) { $env:OPENCLAW_VERSION } else { "" }
$script:NodeBinDir = $null
$script:NvmManaged = $false
$script:RequiredNodeMajor = 22
$script:Arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "x64" }

function Get-LocalAppData {
    if ($env:LOCALAPPDATA) { return $env:LOCALAPPDATA }
    return (Join-Path $HOME "AppData\Local")
}

# ── 工具函数 ──

function Refresh-PathEnv {
    $machinePath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    $env:PATH = "$machinePath;$userPath"
}

function Add-ToUserPath {
    param([string]$Dir)
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($currentPath -notlike "*$Dir*") {
        [Environment]::SetEnvironmentVariable("PATH", "$Dir;$currentPath", "User")
        $env:PATH = "$Dir;$env:PATH"
        Write-Info "已将 $Dir 添加到用户 PATH"
    }
}

function Ensure-ExecutionPolicy {
    try {
        $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
        if ($currentPolicy -eq "Restricted" -or $currentPolicy -eq "AllSigned") {
            Write-Info "当前 PowerShell 执行策略为 $currentPolicy，pnpm 的脚本无法运行"
            Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
            Write-Ok "已将执行策略设置为 RemoteSigned（仅当前用户）"
        }
    } catch {
        Write-Warn "无法自动设置执行策略"
        Write-Host "  请手动执行以下命令后重新打开终端:" -ForegroundColor Yellow
        Write-Host "    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned" -ForegroundColor Cyan
    }
}

function Get-NodeVersion {
    param([string]$NodeExe = "node")
    try {
        $output = & $NodeExe -v 2>$null
        if ($output -match "v(\d+)") {
            $major = [int]$Matches[1]
            if ($major -ge $script:RequiredNodeMajor) {
                return $output.Trim()
            }
        }
    } catch {}
    return $null
}

function Pin-NodePath {
    foreach ($dir in $env:PATH.Split(";")) {
        if (-not $dir) { continue }
        $nodeExe = Join-Path $dir "node.exe"
        if (Test-Path $nodeExe) {
            try {
                $output = & $nodeExe -v 2>$null
                if ($output -match "v(\d+)" -and [int]$Matches[1] -ge $script:RequiredNodeMajor) {
                    $script:NodeBinDir = $dir
                    $rest = ($env:PATH.Split(";") | Where-Object { $_ -ne $dir }) -join ";"
                    $env:PATH = "$dir;$rest"
                    Write-Info "锁定 Node.js v22 路径: $dir"
                    return
                }
            } catch {}
        }
    }
}

function Ensure-NodePriority {
    param([string]$NodeV22Dir)

    # nvm 管理的 Node 不需要手动调整 PATH，nvm use 已处理
    if ($script:NvmManaged) { return }

    if (-not $NodeV22Dir -or -not (Test-Path (Join-Path $NodeV22Dir "node.exe"))) { return }

    $machinePath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    if (-not $machinePath) { return }
    $machineDirs = $machinePath.Split(";") | Where-Object { $_ }

    $hasConflict = $false
    foreach ($dir in $machineDirs) {
        if ($dir -eq $NodeV22Dir) { continue }
        $nodeExe = Join-Path $dir "node.exe"
        if (Test-Path $nodeExe) {
            try {
                $output = & $nodeExe -v 2>$null
                if ($output -match "v(\d+)" -and [int]$Matches[1] -lt $script:RequiredNodeMajor) {
                    $oldVer = $output.Trim()
                    Write-Warn "检测到系统 PATH 中存在低版本 Node.js: $dir ($oldVer)"
                    $hasConflict = $true
                }
            } catch {}
        }
    }

    if (-not $hasConflict) { return }

    # Machine PATH 已有 v22 在最前面则无需处理
    if ($machineDirs[0] -eq $NodeV22Dir) { return }

    Write-Info "正在将 Node.js v22 路径提升到系统 PATH 最前方..."

    $newMachineDirs = @($NodeV22Dir) + ($machineDirs | Where-Object { $_ -ne $NodeV22Dir })
    $newMachinePath = $newMachineDirs -join ";"

    try {
        [Environment]::SetEnvironmentVariable("PATH", $newMachinePath, "Machine")
        Write-Ok "已将 Node.js v22 设为系统默认版本"
    } catch {
        Write-Info "需要管理员权限，正在请求..."
        $escaped = $newMachinePath -replace "'", "''"
        try {
            Start-Process -FilePath "powershell.exe" `
                -ArgumentList "-NoProfile -Command `"[Environment]::SetEnvironmentVariable('PATH','$escaped','Machine')`"" `
                -Verb RunAs -Wait -WindowStyle Hidden
            Write-Ok "已将 Node.js v22 设为系统默认版本"
        } catch {
            Write-Warn "未能修改系统 PATH（用户取消了管理员授权）"
            Write-Info "正在修补 openclaw 启动脚本以使用正确的 Node.js 版本..."
            Patch-OpenclawShim -NodeV22Dir $NodeV22Dir
            return
        }
    }

    Refresh-PathEnv
    $env:PATH = "$NodeV22Dir;$env:PATH"
}

function Patch-OpenclawShim {
    param([string]$NodeV22Dir)

    $nodeExe = Join-Path $NodeV22Dir "node.exe"
    if (-not (Test-Path $nodeExe)) { return }

    $found = Find-OpenclawBinary
    if (-not $found) { return }

    $shimPath = $found.Path
    if ($shimPath -notlike "*.cmd") { return }

    try {
        $content = Get-Content $shimPath -Raw -Encoding UTF8
        if (-not $content) { return }

        # 已经是完整路径则跳过
        if ($content -like "*$nodeExe*") {
            Write-Ok "openclaw 启动脚本已使用正确的 Node.js 路径"
            return
        }

        # 替换裸 node 调用为完整路径
        $patched = $content -replace '(?m)^(@?)node(\.exe)?\s', "`$1`"$nodeExe`" "
        if ($patched -eq $content) {
            $patched = $content -replace '(?m)"node(\.exe)?"\s', "`"$nodeExe`" "
        }

        if ($patched -ne $content) {
            Set-Content -Path $shimPath -Value $patched -Encoding UTF8 -NoNewline
            Write-Ok "已修补 openclaw 启动脚本 → $nodeExe"
        } else {
            Write-Warn "未能自动修补，openclaw.cmd 格式不符合预期"
            Write-Host "  手动修复方法:" -ForegroundColor Yellow
            Write-Host "    1. 打开「系统属性 → 高级 → 环境变量」" -ForegroundColor Yellow
            Write-Host "    2. 在「系统变量」的 PATH 中，将 $NodeV22Dir 移到最前面" -ForegroundColor Yellow
            Write-Host "    3. 或者卸载旧版本 Node.js 后重新打开终端" -ForegroundColor Yellow
        }
    } catch {
        Write-Warn "修补 openclaw 启动脚本失败: $_"
    }
}

function Get-NpmCmd {
    if ($script:NodeBinDir) {
        $cmd = Join-Path $script:NodeBinDir "npm.cmd"
        if (Test-Path $cmd) { return $cmd }
    }
    return "npm"
}

function Get-PnpmCmd {
    if ($script:NodeBinDir) {
        $cmd = Join-Path $script:NodeBinDir "pnpm.cmd"
        if (Test-Path $cmd) { return $cmd }
    }
    $defaultPnpmHome = Join-Path (Get-LocalAppData) "pnpm"
    $cmd = Join-Path $defaultPnpmHome "pnpm.cmd"
    if (Test-Path $cmd) { return $cmd }
    try {
        $resolved = (Get-Command pnpm.cmd -ErrorAction Stop).Source
        if (Test-Path $resolved) { return $resolved }
    } catch {}
    return "pnpm.cmd"
}

function Find-OpenclawBinary {
    $searchDirs = @()

    # pnpm bin -g（实际安装位置）
    try {
        $pnpmCmd = Get-PnpmCmd
        $pnpmBin = (& $pnpmCmd bin -g 2>$null).Trim()
        if ($pnpmBin -and (Test-Path $pnpmBin)) { $searchDirs += $pnpmBin }
    } catch {}

    # PNPM_HOME
    if ($env:PNPM_HOME -and (Test-Path $env:PNPM_HOME)) { $searchDirs += $env:PNPM_HOME }

    # 默认 pnpm 路径 + 全局 store 子目录
    $defaultPnpmHome = Join-Path (Get-LocalAppData) "pnpm"
    if (Test-Path $defaultPnpmHome) {
        $searchDirs += $defaultPnpmHome
        # pnpm 全局安装可能在 pnpm\global\<version>\node_modules\.bin
        $pnpmGlobalDir = Join-Path $defaultPnpmHome "global"
        if (Test-Path $pnpmGlobalDir) {
            Get-ChildItem -Path $pnpmGlobalDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $binDir = Join-Path $_.FullName "node_modules\.bin"
                if (Test-Path $binDir) { $searchDirs += $binDir }
            }
        }
    }

    # npm prefix -g（npm 全局安装路径）
    try {
        $npmCmd = Get-NpmCmd
        $npmPrefix = (& $npmCmd prefix -g 2>$null).Trim()
        if ($npmPrefix) {
            if (Test-Path $npmPrefix) { $searchDirs += $npmPrefix }
            $npmBin = Join-Path $npmPrefix "bin"
            if (Test-Path $npmBin) { $searchDirs += $npmBin }
        }
    } catch {}

    # %AppData%\npm（Windows npm 常见全局目录）
    if ($env:APPDATA) {
        $appDataNpm = Join-Path $env:APPDATA "npm"
        if (Test-Path $appDataNpm) { $searchDirs += $appDataNpm }
    }

    # NodeBinDir
    if ($script:NodeBinDir -and (Test-Path $script:NodeBinDir)) { $searchDirs += $script:NodeBinDir }

    # where.exe 查找
    try {
        $whereResult = & where.exe openclaw 2>$null
        if ($whereResult) {
            $whereResult -split "`r?`n" | ForEach-Object {
                $line = $_.Trim()
                if ($line -and (Test-Path $line)) {
                    $searchDirs += (Split-Path $line -Parent)
                }
            }
        }
    } catch {}

    $searchDirs = $searchDirs | Where-Object { $_ } | Select-Object -Unique
    foreach ($dir in $searchDirs) {
        foreach ($name in @("openclaw.cmd", "openclaw.exe", "openclaw.ps1")) {
            $candidate = Join-Path $dir $name
            if (Test-Path $candidate) {
                return @{ Path = $candidate; Dir = $dir }
            }
        }
    }
    return $null
}

function Get-OpenclawCmd {
    $found = Find-OpenclawBinary
    if ($found) { return $found.Path }
    return "openclaw"
}

function Ensure-PnpmHome {
    $pnpmHome = $env:PNPM_HOME
    if (-not $pnpmHome) {
        $pnpmHome = [Environment]::GetEnvironmentVariable("PNPM_HOME", "User")
    }
    if (-not $pnpmHome) {
        $pnpmHome = Join-Path (Get-LocalAppData) "pnpm"
    }

    $env:PNPM_HOME = $pnpmHome
    if ($env:PATH -notlike "*$pnpmHome*") { $env:PATH = "$pnpmHome;$env:PATH" }

    $savedHome = [Environment]::GetEnvironmentVariable("PNPM_HOME", "User")
    if ($savedHome -ne $pnpmHome) {
        [Environment]::SetEnvironmentVariable("PNPM_HOME", $pnpmHome, "User")
        Write-Info "已持久化 PNPM_HOME=$pnpmHome"
    }

    Add-ToUserPath $pnpmHome
}

function Download-File {
    param([string]$Dest, [string[]]$Urls)
    foreach ($url in $Urls) {
        $hostName = ([Uri]$url).Host
        Write-Info "正在从 $hostName 下载..."
        try {
            Invoke-WebRequest -Uri $url -OutFile $Dest -UseBasicParsing -TimeoutSec 300
            Write-Ok "下载完成"
            return $true
        } catch {
            Write-Warn "从 $hostName 下载失败，尝试备用源..."
        }
    }
    return $false
}

function Get-LatestNodeVersion {
    param([int]$Major)
    $urls = @(
        "https://npmmirror.com/mirrors/node/latest-v${Major}.x/SHASUMS256.txt",
        "https://nodejs.org/dist/latest-v${Major}.x/SHASUMS256.txt"
    )
    foreach ($url in $urls) {
        try {
            $content = (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 15).Content
            if ($content -match "node-(v\d+\.\d+\.\d+)") {
                return $Matches[1]
            }
        } catch {}
    }
    return $null
}

# ── 安装 Node.js ──

function Install-NodeViaNvm {
    $nvmExe = $null
    try {
        $nvmExe = (Get-Command nvm -ErrorAction Stop).Source
    } catch {
        try {
            $nvmOut = & cmd /c "nvm version" 2>$null
            if (-not $nvmOut) { return $false }
        } catch { return $false }
    }

    Write-Info "检测到 nvm-windows，正在使用 nvm 安装 Node.js v22..."

    # 保存原始 node_mirror 设置，安装后复原
    $nvmHome = if ($env:NVM_HOME) { $env:NVM_HOME } else { Join-Path $env:APPDATA "nvm" }
    $nvmSettings = Join-Path $nvmHome "settings.txt"
    $hadMirror = $false
    $oldMirror = $null
    if (Test-Path $nvmSettings) {
        $settingsContent = Get-Content $nvmSettings -ErrorAction SilentlyContinue
        $mirrorLine = $settingsContent | Where-Object { $_ -match '^node_mirror:\s*(.+)' }
        if ($mirrorLine) {
            $hadMirror = $true
            $oldMirror = ($mirrorLine -replace '^node_mirror:\s*', '').Trim()
        }
    }

    & cmd /c "nvm node_mirror https://npmmirror.com/mirrors/node/" 2>$null | Out-Null

    try {
        try { & cmd /c "nvm install 22" 2>$null | Out-Null } catch {
            Write-Warn "nvm install 22 失败: $_"
            return $false
        }

        # nvm use 需要管理员权限（创建符号链接）
        & cmd /c "nvm use 22" 2>$null | Out-Null
        Refresh-PathEnv
        $ver = Get-NodeVersion
        if ($ver) {
            Write-Ok "Node.js $ver 已通过 nvm 安装并切换"
            $script:NvmManaged = $true
            return $true
        }

        # nvm use 可能因权限不足失败，尝试提权
        Write-Info "nvm use 需要管理员权限，正在请求..."
        try {
            Start-Process -FilePath "cmd.exe" `
                -ArgumentList "/c nvm use 22" `
                -Verb RunAs -Wait -WindowStyle Hidden
            Refresh-PathEnv
            $ver = Get-NodeVersion
            if ($ver) {
                Write-Ok "Node.js $ver 已通过 nvm 安装并切换"
                $script:NvmManaged = $true
                return $true
            }
        } catch {
            Write-Warn "nvm use 提权失败（用户可能取消了授权）"
        }

        Write-Warn "nvm 切换 Node.js 版本失败"
        return $false
    } finally {
        # 复原 nvm node_mirror 设置
        if (Test-Path $nvmSettings) {
            if ($hadMirror) {
                & cmd /c "nvm node_mirror $oldMirror" 2>$null | Out-Null
            } else {
                $lines = Get-Content $nvmSettings -ErrorAction SilentlyContinue
                $lines = $lines | Where-Object { $_ -notmatch '^node_mirror:' }
                Set-Content $nvmSettings -Value $lines -ErrorAction SilentlyContinue
            }
        }
    }
}

function Install-NodeDirect {
    Write-Info "正在直接下载安装 Node.js v22..."

    $version = Get-LatestNodeVersion -Major 22
    if (-not $version) {
        Write-Err "无法获取 Node.js 版本信息，请检查网络连接"
        return $false
    }
    Write-Info "最新 LTS 版本: $version"

    $filename = "node-$version-win-$($script:Arch).zip"
    $tmpPath = Join-Path $env:TEMP "openclaw-install"
    $tmpFile = Join-Path $tmpPath $filename
    $extractedName = "node-$version-win-$($script:Arch)"
    $installDir = Join-Path (Get-LocalAppData) "nodejs"

    New-Item -ItemType Directory -Force -Path $tmpPath | Out-Null

    $downloaded = Download-File -Dest $tmpFile -Urls @(
        "https://npmmirror.com/mirrors/node/$version/$filename",
        "https://nodejs.org/dist/$version/$filename"
    )

    if (-not $downloaded) {
        Write-Err "Node.js 下载失败，请检查网络连接"
        return $false
    }

    try {
        Write-Info "正在解压安装..."
        Expand-Archive -Path $tmpFile -DestinationPath $tmpPath -Force
        if (Test-Path $installDir) { Remove-Item $installDir -Recurse -Force }
        Move-Item (Join-Path $tmpPath $extractedName) $installDir

        $env:PATH = "$installDir;$env:PATH"
        Add-ToUserPath $installDir
    } catch {
        Write-Err "安装失败: $_"
        Remove-Item $tmpPath -Recurse -Force -ErrorAction SilentlyContinue
        return $false
    }

    Remove-Item $tmpPath -Recurse -Force -ErrorAction SilentlyContinue

    $ver = Get-NodeVersion
    if ($ver) {
        Write-Ok "Node.js $ver 安装成功"
        return $true
    }
    Write-Warn "Node.js 安装完成但验证失败"
    return $false
}

# ── 安装 Git ──

function Get-GitVersion {
    try {
        $output = & git --version 2>$null
        return $output.Trim()
    } catch {}

    $gitPaths = @(
        (Join-Path $env:ProgramFiles "Git\cmd"),
        (Join-Path ${env:ProgramFiles(x86)} "Git\cmd")
    )
    foreach ($gp in $gitPaths) {
        $gitExe = Join-Path $gp "git.exe"
        if (Test-Path $gitExe) {
            try {
                $output = & $gitExe --version 2>$null
                if (-not ($env:PATH -like "*$gp*")) { $env:PATH = "$gp;$env:PATH" }
                return $output.Trim()
            } catch {}
        }
    }
    return $null
}

function Get-LatestGitRelease {
    $url = "https://registry.npmmirror.com/-/binary/git-for-windows/"
    try {
        $content = (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 15).Content
        $regexMatches = [regex]::Matches($content, "v(\d+)\.(\d+)\.(\d+)\.windows\.(\d+)/")
        if ($regexMatches.Count -eq 0) { return $null }

        $best = $regexMatches | Sort-Object {
            [int]$_.Groups[1].Value * 1000000 + [int]$_.Groups[2].Value * 10000 +
            [int]$_.Groups[3].Value * 100 + [int]$_.Groups[4].Value
        } -Descending | Select-Object -First 1

        $version = "$($best.Groups[1].Value).$($best.Groups[2].Value).$($best.Groups[3].Value)"
        $winBuild = $best.Groups[4].Value
        $tag = "v$version.windows.$winBuild"
        $fileVersion = if ($winBuild -eq "1") { $version } else { "$version.$winBuild" }
        return @{ Version = $version; Tag = $tag; FileVersion = $fileVersion }
    } catch {}

    try {
        $ghUrl = "https://api.github.com/repos/git-for-windows/git/releases/latest"
        $content = (Invoke-WebRequest -Uri $ghUrl -UseBasicParsing -TimeoutSec 15).Content
        if ($content -match '\x22tag_name\x22\s*:\s*\x22(v(\d+\.\d+\.\d+)\.windows\.(\d+))\x22') {
            $version = $Matches[2]; $winBuild = $Matches[3]; $tag = $Matches[1]
            $fileVersion = if ($winBuild -eq "1") { $version } else { "$version.$winBuild" }
            return @{ Version = $version; Tag = $tag; FileVersion = $fileVersion }
        }
    } catch {}
    return $null
}

function Install-GitViaWinget {
    try {
        Get-Command winget -ErrorAction Stop | Out-Null
    } catch { return $false }

    Write-Info "检测到 winget，正在安装 Git..."
    try {
        & winget install --id Git.Git -e --source winget --silent --accept-package-agreements --accept-source-agreements 2>$null | Out-Null
    } catch {
        Write-Warn "winget 命令返回了非零退出码，检查 Git 是否已可用..."
    }

    Refresh-PathEnv
    $ver = Get-GitVersion
    if ($ver) {
        Write-Ok "$ver 已可用"
        return $true
    }
    Write-Warn "winget 安装后仍未检测到 Git"
    return $false
}

function Install-GitDirect {
    Write-Info "正在下载 Git for Windows..."

    $release = Get-LatestGitRelease
    if (-not $release) {
        Write-Err "无法获取 Git 版本信息，请检查网络连接"
        return $false
    }
    Write-Info "最新版本: Git $($release.FileVersion)"

    $archStr = if ($script:Arch -eq "arm64") { "arm64" } else { "64-bit" }
    $filename = "Git-$($release.FileVersion)-$archStr.exe"
    $tmpPath = Join-Path $env:TEMP "openclaw-install"
    $tmpFile = Join-Path $tmpPath $filename

    New-Item -ItemType Directory -Force -Path $tmpPath | Out-Null

    $downloaded = Download-File -Dest $tmpFile -Urls @(
        "https://registry.npmmirror.com/-/binary/git-for-windows/$($release.Tag)/$filename",
        "https://github.com/git-for-windows/git/releases/download/$($release.Tag)/$filename"
    )

    if (-not $downloaded) {
        Write-Err "Git 下载失败，请检查网络连接"
        Remove-Item $tmpPath -Recurse -Force -ErrorAction SilentlyContinue
        return $false
    }

    Write-Info "正在静默安装 Git..."
    try {
        Start-Process -FilePath $tmpFile -ArgumentList "/VERYSILENT","/NORESTART","/NOCANCEL","/SP-","/CLOSEAPPLICATIONS","/RESTARTAPPLICATIONS" -Wait
        Refresh-PathEnv

        $ver = Get-GitVersion
        if ($ver) {
            Write-Ok "$ver 安装成功"
            Remove-Item $tmpPath -Recurse -Force -ErrorAction SilentlyContinue
            return $true
        }
    } catch {
        Write-Err "Git 安装失败: $_"
    }

    Remove-Item $tmpPath -Recurse -Force -ErrorAction SilentlyContinue
    return $false
}

# ── 主流程步骤 ──

function Test-NvmInstalled {
    try { $null = & cmd /c "nvm version" 2>$null; return $true } catch {}
    try { Get-Command nvm -ErrorAction Stop | Out-Null; return $true } catch {}
    return $false
}

function Test-NvmNodeActive {
    param([int]$Major)
    try {
        $list = & cmd /c "nvm list" 2>$null
        if ($list -match "\*\s+$Major\.") { return $true }
    } catch {}
    return $false
}

function Use-NodeV22Dir {
    param([string]$Dir)
    $script:NodeBinDir = $Dir
    $rest = ($env:PATH.Split(";") | Where-Object { $_ -ne $Dir }) -join ";"
    $env:PATH = "$Dir;$rest"
    Add-ToUserPath $Dir
    Ensure-NodePriority -NodeV22Dir $Dir
}

function Step-CheckNode {
    Write-Step "步骤 1/7: 准备 Node.js 环境"

    $hasNvm = Test-NvmInstalled

    # 如果有 nvm，优先尝试通过 nvm 管理 Node 版本
    if ($hasNvm) {
        Write-Info "检测到 nvm-windows..."

        # 检查 nvm 当前激活的版本是否已经是 v22+
        if (Test-NvmNodeActive -Major 22) {
            $ver = Get-NodeVersion
            if ($ver) {
                Write-Ok "Node.js $ver 已通过 nvm 激活，版本满足要求 (>= 22)"
                Pin-NodePath
                $script:NvmManaged = $true
                return $true
            }
        }

        # nvm 没有激活 v22，尝试安装并切换
        if (Install-NodeViaNvm) {
            Pin-NodePath
            return $true
        }

        # nvm 切换失败，尝试使用已有的 v22（之前直接安装的）
        Write-Warn "nvm 切换 Node.js v22 失败（通常需要管理员权限）"
        Write-Info "正在查找其他可用的 Node.js v22..."
    }

    # 检查脚本之前直接安装过的路径
    $scriptInstallDir = Join-Path (Get-LocalAppData) "nodejs"
    $scriptNodeExe = Join-Path $scriptInstallDir "node.exe"
    if (Test-Path $scriptNodeExe) {
        $ver = Get-NodeVersion -NodeExe $scriptNodeExe
        if ($ver) {
            Write-Ok "Node.js $ver 已安装，版本满足要求 (>= 22)"
            Use-NodeV22Dir $scriptInstallDir
            return $true
        }
    }

    # 从 PATH 中查找合格版本
    $ver = Get-NodeVersion
    if ($ver) {
        Write-Ok "Node.js $ver 已安装，版本满足要求 (>= 22)"
        Pin-NodePath
        if ($script:NodeBinDir) { Ensure-NodePriority -NodeV22Dir $script:NodeBinDir }
        return $true
    }

    $existingVer = try { & node -v 2>$null } catch { $null }
    if ($existingVer) {
        Write-Warn "检测到 Node.js $existingVer，版本过低，需要 v22 以上"
    } else {
        Write-Warn "未检测到 Node.js"
    }

    Write-Info "正在自动安装 Node.js v22..."
    if (Install-NodeDirect) {
        Pin-NodePath
        if ($script:NodeBinDir) { Ensure-NodePriority -NodeV22Dir $script:NodeBinDir }
        return $true
    }

    Write-Err "所有安装方式均失败，请检查网络连接后重试"
    if ($hasNvm) {
        Write-Host ""
        Write-Host "  建议以管理员身份打开 PowerShell 后执行:" -ForegroundColor Yellow
        Write-Host "    nvm install 22" -ForegroundColor Cyan
        Write-Host "    nvm use 22" -ForegroundColor Cyan
        Write-Host "  然后重新运行本安装脚本" -ForegroundColor Yellow
    }
    return $false
}

function Step-CheckGit {
    Write-Step "步骤 2/7: 准备 Git 环境"

    $ver = Get-GitVersion
    if ($ver) {
        Write-Ok "$ver 已安装"
        return $true
    }

    Write-Warn "未检测到 Git，正在自动安装..."

    if (Install-GitDirect) { return $true }
    if (Install-GitViaWinget) { return $true }

    Write-Err "Git 自动安装失败，请手动安装 Git 后重试"
    Write-Host "  下载地址: https://git-scm.com/downloads"
    return $false
}

function Step-SetMirror {
    Write-Step "步骤 3/7: 设置国内 npm 镜像"

    $env:npm_config_registry = "https://registry.npmmirror.com"
    Write-Ok "npm 镜像已临时设置为 https://registry.npmmirror.com（仅本次安装生效）"
    return $true
}

function Step-InstallPnpm {
    Write-Step "步骤 4/7: 安装 pnpm"

    $pnpmCmd = Get-PnpmCmd
    try {
        $pnpmVer = (& $pnpmCmd -v 2>$null).Trim()
        if ($pnpmVer) {
            Write-Ok "pnpm $pnpmVer 已安装，跳过安装步骤"
            Ensure-PnpmHome
            return $true
        }
    } catch {}

    $npmCmd = Get-NpmCmd
    Write-Info "正在安装 pnpm..."
    try {
        $savedEAP = $ErrorActionPreference
        $ErrorActionPreference = "SilentlyContinue"
        & $npmCmd install -g pnpm 2>$null | Out-Null
        $npmExit = $LASTEXITCODE
        $ErrorActionPreference = $savedEAP
        if ($npmExit -ne 0) { throw "npm install -g pnpm 失败 (exit code: $npmExit)" }
        $pnpmCmd = Get-PnpmCmd
        Write-Info "正在验证 pnpm 安装..."
        $pnpmVer = (& $pnpmCmd -v 2>$null).Trim()
        Write-Ok "pnpm $pnpmVer 安装成功"

        Write-Info "正在配置 pnpm 全局路径 (pnpm setup)..."
        try { & $pnpmCmd setup 2>$null | Out-Null } catch { Write-Warn "pnpm setup 执行未成功，不影响后续安装" }

        Ensure-PnpmHome
        return $true
    } catch {
        Write-Err "pnpm 安装失败: $_"
        return $false
    }
}

function Run-PnpmInstall {
    param([string]$PnpmCmd, [string]$Label = "安装")

    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "cmd.exe"
        $pkgSpec = if ($script:OpenClawVersion) { "openclaw@$($script:OpenClawVersion)" } else { "openclaw@latest" }
        $psi.Arguments = "/c `"$PnpmCmd`" add -g $pkgSpec"
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true

        # 确保子进程使用正确版本的 Node.js
        if ($script:NodeBinDir) {
            $childPath = $env:PATH
            $cleanParts = $childPath.Split(";") | Where-Object {
                if (-not $_) { return $false }
                $nodeInDir = Join-Path $_ "node.exe"
                if ((Test-Path $nodeInDir) -and ($_ -ne $script:NodeBinDir)) { return $false }
                return $true
            }
            $psi.EnvironmentVariables["PATH"] = "$($script:NodeBinDir);$($cleanParts -join ';')"
        }

        $proc = [System.Diagnostics.Process]::Start($psi)
        $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
        $stderrTask = $proc.StandardError.ReadToEndAsync()
    } catch {
        Write-Err "启动${Label}进程失败: $_"
        return @{ Success = $false; Stderr = ""; Stdout = "" }
    }

    $progress = 0
    $width = 30
    while (-not $proc.HasExited) {
        if ($progress -lt 30) { $progress += 3 }
        elseif ($progress -lt 60) { $progress += 2 }
        elseif ($progress -lt 90) { $progress += 1 }
        if ($progress -gt 90) { $progress = 90 }
        $filled = [math]::Floor($progress * $width / 100)
        $empty = $width - $filled
        $bar = ([string]::new([char]0x2588, $filled)) + ([string]::new([char]0x2591, $empty))
        Write-Host "`r  ${Label}进度 [$bar] $($progress.ToString().PadLeft(3))%" -NoNewline
        Start-Sleep -Seconds 1
    }

    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()

    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    $fullBar = [string]::new([char]0x2588, $width)
    if ($proc.ExitCode -eq 0) {
        Write-Host "`r  ${Label}进度 [$fullBar] 100%"
        return @{ Success = $true; Stderr = $stderr; Stdout = $stdout }
    }

    Write-Host "`r  ${Label}进度 [$fullBar] 失败"
    return @{ Success = $false; Stderr = $stderr; Stdout = $stdout; ExitCode = $proc.ExitCode }
}

function Step-InstallOpenClaw {
    Write-Step "步骤 5/7: 安装 OpenClaw"

    $gitVer = Get-GitVersion
    if (-not $gitVer) {
        Write-Err "Git 不可用，OpenClaw 的依赖需要 Git 来解析"
        Write-Host "  请先安装 Git: https://git-scm.com/downloads" -ForegroundColor Yellow
        return $false
    }

    if ($script:OpenClawVersion) {
        Write-Info "正在安装 OpenClaw v$($script:OpenClawVersion)，请耐心等待..."
    } else {
        Write-Info "正在安装 OpenClaw 最新版，请耐心等待..."
    }

    $pnpmCmd = Get-PnpmCmd
    if (-not (Test-Path $pnpmCmd -ErrorAction SilentlyContinue)) {
        try { Get-Command $pnpmCmd -ErrorAction Stop | Out-Null } catch {
            Write-Err "找不到 pnpm 命令"
            return $false
        }
    }

    # 通过环境变量临时设置 git URL 重写规则，不修改用户的 git config
    $env:GIT_CONFIG_COUNT = "2"
    $env:GIT_CONFIG_KEY_0 = "url.https://github.com/.insteadOf"
    $env:GIT_CONFIG_VALUE_0 = "git+ssh://git@github.com/"
    $env:GIT_CONFIG_KEY_1 = "url.https://github.com/.insteadOf"
    $env:GIT_CONFIG_VALUE_1 = "ssh://git@github.com/"

    function Try-InstallWithCleanup([string]$PnpmCmd, [ref]$Result) {
        $combinedOutput = "$($Result.Value.Stderr)`n$($Result.Value.Stdout)"
        $isPnpmStoreError = $combinedOutput -match "VIRTUAL_STORE_DIR" -or $combinedOutput -match "broken lockfile" -or $combinedOutput -match "not compatible with current pnpm"
        if ($isPnpmStoreError) {
            Write-Warn "检测到 pnpm 全局 store 状态不兼容，正在清理后重试..."
            $pnpmGlobalDir = Join-Path (Get-LocalAppData) "pnpm\global"
            if (Test-Path $pnpmGlobalDir) {
                Remove-Item $pnpmGlobalDir -Recurse -Force -ErrorAction SilentlyContinue
                Write-Info "已清理 $pnpmGlobalDir"
            }
            try { & $PnpmCmd store prune 2>$null } catch {}
            $retryResult = Run-PnpmInstall -PnpmCmd $PnpmCmd -Label "重试安装"
            $Result.Value = $retryResult
            return $retryResult.Success
        }
        return $false
    }

    function Clear-GitConfigEnv {
        Remove-Item Env:GIT_CONFIG_COUNT -ErrorAction SilentlyContinue
        for ($i = 0; $i -lt 2; $i++) {
            Remove-Item "Env:GIT_CONFIG_KEY_$i" -ErrorAction SilentlyContinue
            Remove-Item "Env:GIT_CONFIG_VALUE_$i" -ErrorAction SilentlyContinue
        }
    }

    function On-InstallSuccess {
        Clear-GitConfigEnv
        Write-Ok "OpenClaw 安装完成"
        Refresh-PathEnv
        Ensure-PnpmHome
        Ensure-ExecutionPolicy
        $found = Find-OpenclawBinary
        if ($found) {
            Add-ToUserPath $found.Dir
            Write-Info "OpenClaw 安装位置: $($found.Dir)"
        } else {
            try {
                $pnpmBin = (& $pnpmCmd bin -g 2>$null).Trim()
                if ($pnpmBin -and (Test-Path $pnpmBin)) {
                    Add-ToUserPath $pnpmBin
                    Write-Info "pnpm 全局 bin 目录: $pnpmBin"
                }
            } catch {}
        }
        return $true
    }

    # ── GitHub 镜像相关辅助函数 ──

    function Set-GitMirror([string]$Mirror) {
        $env:GIT_CONFIG_COUNT = "3"
        $env:GIT_CONFIG_KEY_2 = "url.${Mirror}.insteadOf"
        $env:GIT_CONFIG_VALUE_2 = "https://github.com/"
    }

    function Clear-GitMirror {
        $env:GIT_CONFIG_COUNT = "2"
        Remove-Item Env:GIT_CONFIG_KEY_2 -ErrorAction SilentlyContinue
        Remove-Item Env:GIT_CONFIG_VALUE_2 -ErrorAction SilentlyContinue
    }

    function Install-WithMirrors {
        Write-Warn "你已选择使用第三方 GitHub 镜像，请知悉潜在风险"
        $gitHubMirrors = @(
            "https://bgithub.xyz/",
            "https://kkgithub.com/",
            "https://github.ur1.fun/",
            "https://ghproxy.net/https://github.com/",
            "https://gitclone.com/github.com/"
        )

        # 并发探测所有镜像连通性，筛选可用的
        Write-Info "正在探测可用镜像..."
        $available = @()
        $jobs = @()
        foreach ($m in $gitHubMirrors) {
            $testUrl = $m.TrimEnd('/') + "/"
            $jobs += @{ Mirror = $m; Request = $null }
            try {
                $req = [System.Net.HttpWebRequest]::Create($testUrl)
                $req.Method = "HEAD"
                $req.Timeout = 6000
                $req.AllowAutoRedirect = $true
                $jobs[-1].Request = $req
            } catch {}
        }
        foreach ($j in $jobs) {
            if (-not $j.Request) { continue }
            try {
                $resp = $j.Request.GetResponse()
                $resp.Close()
                $available += $j.Mirror
                Write-Ok "镜像可用: $($j.Mirror)"
            } catch {
                Write-Warn "镜像不可用: $($j.Mirror)"
            }
        }

        if ($available.Count -eq 0) {
            Write-Err "所有镜像均不可达"
            return $null
        }

        foreach ($mirror in $available) {
            try {
                Set-GitMirror $mirror
                Write-Info "正在使用镜像 $mirror 安装..."
                $r = Run-PnpmInstall -PnpmCmd $pnpmCmd -Label "安装"
                Clear-GitMirror
                if ($r.Success) { return $r }
                $rr = $r
                if (Try-InstallWithCleanup $pnpmCmd ([ref]$rr)) { return $rr }
            } catch {
                Clear-GitMirror
            }
        }
        return $null
    }

    function Show-GitHubChoiceMenu {
        Write-Host ""
        Write-Host "  部分依赖需要从 GitHub 下载，但当前无法连接 GitHub。" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  请选择解决方案:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   1) 使用 GitHub 社区镜像继续安装" -ForegroundColor White
        Write-Host "      镜像由第三方提供，存在内容被篡改的风险" -ForegroundColor DarkGray
        Write-Host "   2) 手动配置代理后重试" -ForegroundColor White
        Write-Host "      需要你有可用的代理工具（推荐）" -ForegroundColor DarkGray
        Write-Host "   0) 退出安装" -ForegroundColor White
        Write-Host ""
        return (Read-Host "  请选择 [0-2]").Trim()
    }

    function Show-ProxyGuide {
        Write-Host ""
        Write-Host "  请在代理工具开启后，参考以下命令设置 git 代理:" -ForegroundColor Yellow
        Write-Host "    git config --global http.https://github.com.proxy http://127.0.0.1:7890" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  然后重新运行本安装脚本。安装完成后可还原:" -ForegroundColor Yellow
        Write-Host "    git config --global --unset http.https://github.com.proxy" -ForegroundColor Cyan
    }

    # ── 安装 ──

    $result = Run-PnpmInstall -PnpmCmd $pnpmCmd -Label "安装"
    if ($result.Success) { return (On-InstallSuccess) }
    if (Try-InstallWithCleanup $pnpmCmd ([ref]$result)) { return (On-InstallSuccess) }

    # 直连安装也失败了，给用户兜底选择
    $combinedOutput = "$($result.Stderr)`n$($result.Stdout)"
    $isGitHubError = $combinedOutput -match "github\.com" -and ($combinedOutput -match "git ls-remote" -or $combinedOutput -match "fatal:" -or $combinedOutput -match "Could not resolve" -or $combinedOutput -match "timed out")

    if ($isGitHubError) {
        Write-Warn "直连安装失败，GitHub 访问异常"
        $ghChoice = Show-GitHubChoiceMenu
        if ($ghChoice -eq "1") {
            $mirrorResult = Install-WithMirrors
            if ($mirrorResult -and $mirrorResult.Success) { return (On-InstallSuccess) }
            Write-Err "所有镜像均安装失败"
        }
        elseif ($ghChoice -eq "2") {
            Show-ProxyGuide
        }
        Clear-GitConfigEnv
        return $false
    }

    # 非 GitHub 网络问题的通用错误
    Clear-GitConfigEnv
    Write-Err "OpenClaw 安装失败 (exit code: $($result.ExitCode))"
    if ($result.Stderr) {
        Write-Err "错误信息:"
        $result.Stderr.Trim().Split("`n") | ForEach-Object { Write-Host "         $_" -ForegroundColor Red }
    }
    if ($result.Stdout) {
        Write-Info "安装输出:"
        $result.Stdout.Trim().Split("`n") | Select-Object -Last 15 | ForEach-Object { Write-Host "         $_" }
    }
    return $false
}

function Step-Verify {
    Write-Step "步骤 6/7: 验证安装结果"

    Refresh-PathEnv
    Ensure-PnpmHome
    Ensure-ExecutionPolicy

    $found = Find-OpenclawBinary
    if ($found) {
        $binDir = $found.Dir
        if ($env:PATH -notlike "*$binDir*") {
            $env:PATH = "$binDir;$env:PATH"
        }
        Add-ToUserPath $binDir
        Write-Info "OpenClaw 安装位置: $binDir"

        $ver = $null
        try { $ver = (& $found.Path -v 2>$null).Trim() } catch {}
        if ($ver) {
            Write-Ok "OpenClaw $ver 安装成功！"
            Write-Host "`n  🦞 恭喜！你的龙虾已就位！`n" -ForegroundColor Green
            return $true
        }
    }

    # 再尝试 pnpm bin -g 兜底
    try {
        $pnpmCmd = Get-PnpmCmd
        $pnpmBin = (& $pnpmCmd bin -g 2>$null).Trim()
        if ($pnpmBin -and (Test-Path $pnpmBin)) {
            $env:PATH = "$pnpmBin;$env:PATH"
            Add-ToUserPath $pnpmBin
            Write-Info "已将 pnpm 全局 bin 目录添加到 PATH: $pnpmBin"

            $openclawCmd = Join-Path $pnpmBin "openclaw.cmd"
            if (Test-Path $openclawCmd) {
                $ver = $null
                try { $ver = (& $openclawCmd -v 2>$null).Trim() } catch {}
                if ($ver) {
                    Write-Ok "OpenClaw $ver 安装成功！"
                    Write-Host "`n  🦞 恭喜！你的龙虾已就位！`n" -ForegroundColor Green
                    return $true
                }
            }
        }
    } catch {}

    Write-Err "安装完成但无法找到 openclaw 可执行文件"
    Write-Host ""
    Write-Host "  请尝试以下步骤排查:" -ForegroundColor Yellow
    Write-Host "    1. 关闭当前终端，打开一个新的 PowerShell 窗口" -ForegroundColor Yellow
    Write-Host "    2. 运行 openclaw -v 检查是否可用" -ForegroundColor Yellow
    Write-Host "    3. 如果仍然不可用，运行以下命令查看 pnpm 全局 bin 目录:" -ForegroundColor Yellow
    Write-Host "       pnpm bin -g" -ForegroundColor Cyan
    Write-Host "    4. 将输出的目录手动添加到系统 PATH 环境变量" -ForegroundColor Yellow
    Write-Host ""
    return $false
}

function Step-Onboard {
    Write-Step "步骤 7/7: 配置 OpenClaw"

    Write-Host "  请选择 AI 厂商:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   1) openai         - OpenAI (GPT-5.1 Codex, o3, o4-mini 等)"
    Write-Host "   2) anthropic      - Anthropic (Claude Sonnet 4.5, Opus 4.6)"
    Write-Host "   3) gemini         - Google Gemini (2.5 Pro, 2.5 Flash)"
    Write-Host "   4) mistral        - Mistral (Large, Codestral)"
    Write-Host "   5) zai            - 智谱 AI (GLM-5, GLM-4.7)"
    Write-Host "   6) moonshot       - Moonshot (Kimi K2.5)"
    Write-Host "   7) kimi-coding    - Kimi Coding (K2.5)"
    Write-Host "   8) qianfan        - 百度千帆 (ERNIE 4.5, DeepSeek R1)"
    Write-Host "   9) xiaomi         - 小米 (MiMo V2 Flash)"
    Write-Host "  10) custom         - 自定义 (OpenAI/Anthropic 兼容接口)"
    Write-Host "   0) 跳过配置"
    Write-Host ""

    $choice = (Read-Host "  请输入编号 [0-10]").Trim()

    if ($choice -eq "0") {
        Write-Info "已跳过配置"
        Write-Info "重新执行本安装脚本或运行 openclaw onboard 即可进入配置"
        return $true
    }

    $providerMap = @{
        "1"  = @{ Name="openai";      AuthChoice="openai-api-key";     KeyFlag="--openai-api-key" }
        "2"  = @{ Name="anthropic";   AuthChoice="apiKey";              KeyFlag="--anthropic-api-key" }
        "3"  = @{ Name="gemini";      AuthChoice="gemini-api-key";      KeyFlag="--gemini-api-key" }
        "4"  = @{ Name="mistral";     AuthChoice="mistral-api-key";     KeyFlag="--mistral-api-key" }
        "5"  = @{ Name="zai";         AuthChoice="zai-api-key";         KeyFlag="--zai-api-key" }
        "6"  = @{ Name="moonshot";    AuthChoice="moonshot-api-key";    KeyFlag="--moonshot-api-key" }
        "7"  = @{ Name="kimi-coding"; AuthChoice="kimi-code-api-key";   KeyFlag="--kimi-code-api-key" }
        "8"  = @{ Name="qianfan";     AuthChoice="qianfan-api-key";     KeyFlag="--qianfan-api-key" }
        "9"  = @{ Name="xiaomi";      AuthChoice="xiaomi-api-key";      KeyFlag="--xiaomi-api-key" }
        "10" = @{ Name="custom";      AuthChoice="custom-api-key";      KeyFlag="--custom-api-key" }
    }

    if (-not $providerMap.ContainsKey($choice)) {
        Write-Warn "无效选择，跳过配置"
        return $true
    }

    $provider = $providerMap[$choice]
    Write-Host ""
    $apiKey = (Read-Host "  请输入 API Key").Trim()
    if (-not $apiKey) {
        Write-Err "API Key 不能为空"
        return $false
    }

    $openclawCmd = Get-OpenclawCmd

    $onboardArgs = @(
        "onboard", "--non-interactive",
        "--accept-risk",
        "--mode", "local",
        "--auth-choice", $provider.AuthChoice,
        $provider.KeyFlag, $apiKey,
        "--secret-input-mode", "plaintext",
        "--gateway-port", "18789",
        "--gateway-bind", "loopback",
        "--install-daemon",
        "--daemon-runtime", "node",
        "--skip-skills"
    )

    $customBaseUrl = ""
    $customModelId = ""
    if ($provider.Name -eq "custom") {
        Write-Host ""
        $customBaseUrl = (Read-Host "  请输入自定义 Base URL").Trim()
        $customModelId = (Read-Host "  请输入自定义 Model ID").Trim()

        if ($customBaseUrl) { $onboardArgs += @("--custom-base-url", $customBaseUrl) }
        if ($customModelId) { $onboardArgs += @("--custom-model-id", $customModelId) }
        $onboardArgs += @("--custom-compatibility", "openai")
    }

    Write-Info "正在配置 OpenClaw..."
    $savedEAP = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    & $openclawCmd @onboardArgs *>$null
    $onboardExit = $LASTEXITCODE
    $ErrorActionPreference = $savedEAP

    $configFile = Join-Path $env:USERPROFILE ".openclaw\openclaw.json"
    if (Test-Path $configFile) {
        Write-Ok "OpenClaw 配置完成！"
    } else {
        Write-Err "配置失败，请检查 API Key 是否正确"
        return $false
    }

    # 选择默认模型
    if ($provider.Name -ne "custom") {
        $modelMap = @{
            "openai"      = @(
                @{ Id="openai/gpt-5.1-codex"; Label="GPT-5.1 Codex" },
                @{ Id="openai/o3"; Label="o3" },
                @{ Id="openai/o4-mini"; Label="o4-mini" },
                @{ Id="openai/gpt-4.1"; Label="GPT-4.1" }
            )
            "anthropic"   = @(
                @{ Id="anthropic/claude-sonnet-4-5"; Label="Claude Sonnet 4.5" },
                @{ Id="anthropic/claude-opus-4-6"; Label="Claude Opus 4.6" }
            )
            "gemini"      = @(
                @{ Id="gemini/gemini-2.5-pro"; Label="Gemini 2.5 Pro" },
                @{ Id="gemini/gemini-2.5-flash"; Label="Gemini 2.5 Flash" }
            )
            "mistral"     = @(
                @{ Id="mistral/mistral-large-latest"; Label="Mistral Large" },
                @{ Id="mistral/codestral-latest"; Label="Codestral" }
            )
            "zai"         = @(
                @{ Id="zai/glm-5"; Label="GLM-5" },
                @{ Id="zai/glm-4.7"; Label="GLM-4.7" }
            )
            "moonshot"    = @(
                @{ Id="moonshot/kimi-k2.5"; Label="Kimi K2.5" },
                @{ Id="moonshot/kimi-k2-thinking"; Label="Kimi K2 Thinking" },
                @{ Id="moonshot/kimi-k2-thinking-turbo"; Label="Kimi K2 Thinking Turbo" }
            )
            "kimi-coding" = @(
                @{ Id="kimi-coding/k2p5"; Label="Kimi K2.5 (Coding)" }
            )
            "qianfan"     = @(
                @{ Id="qianfan/ernie-4.5-turbo-vl-32k"; Label="ERNIE 4.5 Turbo" },
                @{ Id="qianfan/deepseek-r1"; Label="DeepSeek R1" }
            )
            "xiaomi"      = @(
                @{ Id="xiaomi/mimo-v2-flash"; Label="MiMo V2 Flash" }
            )
        }

        $models = $modelMap[$provider.Name]
        if ($models -and $models.Count -gt 0) {
            Write-Host ""
            Write-Host "  请选择默认模型:" -ForegroundColor Cyan
            Write-Host ""
            for ($i = 0; $i -lt $models.Count; $i++) {
                Write-Host "   $($i+1)) $($models[$i].Label)"
            }
            Write-Host "   0) 跳过"
            Write-Host ""
            $modelChoice = (Read-Host "  请选择 [0-$($models.Count)]").Trim()

            if ($modelChoice -ne "0" -and $modelChoice) {
                $idx = [int]$modelChoice - 1
                if ($idx -ge 0 -and $idx -lt $models.Count) {
                    $selectedModel = $models[$idx]
                    Write-Info "正在设置默认模型: $($selectedModel.Id)"
                    try {
                        & $openclawCmd models set $selectedModel.Id 2>$null | Out-Null
                        Write-Ok "默认模型已设置为 $($selectedModel.Label)"
                    } catch {
                        Write-Warn "模型设置未成功，可稍后通过 openclaw models set 手动设置"
                    }
                }
            }
        }
    }

    Write-Host ""
    Write-Info "正在打开 OpenClaw 控制面板..."
    try { & $openclawCmd dashboard 2>$null } catch { Start-Process "http://127.0.0.1:18789" }
    Write-Ok "已在后台启动，请访问 http://127.0.0.1:18789"

    return $true
}

# ── 主函数 ──

function Main {
    Write-Host ""
    Write-Host "  🦞 OpenClaw 一键安装脚本" -ForegroundColor Green
    Write-Host "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host ""

    Refresh-PathEnv

    # 检测是否已安装（全面搜索）
    $existingVer = $null
    $found = Find-OpenclawBinary
    if ($found) {
        try { $existingVer = (& $found.Path -v 2>$null).Trim() } catch {}
    }
    if (-not $existingVer) {
        try { $existingVer = (& openclaw -v 2>$null).Trim() } catch {}
    }
    if ($existingVer -and -not $script:OpenClawVersion) {
        if ($found) { Add-ToUserPath $found.Dir }
        Ensure-ExecutionPolicy
        Write-Ok "OpenClaw $existingVer 已安装，无需重复安装"
        Write-Host "`n  🦞 你的龙虾已就位！`n" -ForegroundColor Green
        $reconfig = (Read-Host "  是否要重新配置 OpenClaw? [y/N]").Trim()
        if ($reconfig -match "^[Yy]") {
            Step-Onboard | Out-Null
        }
        return
    }

    if (-not (Step-CheckNode))       { Write-Host "`n按任意键退出..."; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown"); return }
    if (-not (Step-CheckGit))        { Write-Host "`n按任意键退出..."; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown"); return }
    if (-not (Step-SetMirror))       { Write-Host "`n按任意键退出..."; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown"); return }
    if (-not (Step-InstallPnpm))     { Write-Host "`n按任意键退出..."; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown"); return }
    if (-not (Step-InstallOpenClaw)) { Write-Host "`n按任意键退出..."; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown"); return }
    if (-not (Step-Verify))          { Write-Host "`n按任意键退出..."; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown"); return }
    Step-Onboard | Out-Null

    Write-Host ""
    Write-Host "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host "  🦞 安装完成！" -ForegroundColor Green
    Write-Host "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host ""
}

Main

# 安装完成后刷新当前进程的 PATH，让 openclaw 立即可用
$machinePath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
$env:PATH = "$userPath;$machinePath"
