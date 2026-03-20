[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
if ($PSVersionTable.PSVersion.Major -ge 6) {
    $OutputEncoding = [System.Text.Encoding]::UTF8
}

$ErrorActionPreference = 'Stop'
$script:VERSION = '1.0.0'

# ─── Argument Parsing (compatible with irm | iex) ────────────────────────────

$script:DryRun      = $false
$script:Yes         = $false
$script:KeepConfig  = $false
$script:WrappedOnly = $false
$script:Lang        = 'zh'
$script:NoColor     = $false

$script:_args = if ($args) { $args } else { @() }
for ($i = 0; $i -lt $script:_args.Count; $i++) {
    switch ($script:_args[$i]) {
        '-DryRun'      { $script:DryRun = $true }
        '-Yes'         { $script:Yes = $true }
        '-y'           { $script:Yes = $true }
        '-KeepConfig'  { $script:KeepConfig = $true }
        '-WrappedOnly' { $script:WrappedOnly = $true }
        '-Lang'        { $i++; $script:Lang = $script:_args[$i] }
        '-NoColor'     { $script:NoColor = $true }
        '-Version'     { Write-Host "clawfather-uninstall v$script:VERSION"; exit 0 }
        '-Help'        { $script:_showHelp = $true }
        '-h'           { $script:_showHelp = $true }
    }
}

$DryRun = $script:DryRun; $Yes = $script:Yes; $KeepConfig = $script:KeepConfig
$WrappedOnly = $script:WrappedOnly; $Lang = $script:Lang; $NoColor = $script:NoColor

if ($script:_showHelp) {
    @"
Clawfather 一键卸载脚本 — OpenClaw Wrapped Uninstaller (Windows)

用法: .\uninstall.ps1 [参数]

参数:
  -DryRun          只生成报告，不执行卸载
  -Yes, -y         跳过确认提示
  -KeepConfig      保留配置和工作区文件
  -WrappedOnly     只看 Wrapped 报告，不卸载
  -Lang zh|en      语言 (默认 zh)
  -NoColor         纯文本输出
  -Version         显示版本
  -Help, -h        显示帮助

示例:
  .\uninstall.ps1                        # 交互式卸载 + Wrapped
  .\uninstall.ps1 -WrappedOnly           # 只看报告，不卸载
  .\uninstall.ps1 -DryRun                # 预览将删除的内容
  .\uninstall.ps1 -Yes -Lang en          # 非交互式英文卸载
  irm https://clawfather.cn/uninstall.ps1 | iex   # 一键运行
"@
    exit 0
}

# ─── Color Helpers ────────────────────────────────────────────────────────────

$script:UseColor = (-not $NoColor) -and ($Host.UI.SupportsVirtualTerminal -or $env:WT_SESSION)

if ($script:UseColor) {
    $e = [char]27
    $script:RST = "$e[0m";  $script:BLD = "$e[1m";  $script:DIM = "$e[2m"
    $script:RED = "$e[31m"; $script:GRN = "$e[32m"; $script:YLW = "$e[33m"
    $script:BLU = "$e[34m"; $script:MAG = "$e[35m"; $script:CYN = "$e[36m"
    $script:GRY = "$e[90m"
} else {
    $script:RST = ''; $script:BLD = ''; $script:DIM = ''
    $script:RED = ''; $script:GRN = ''; $script:YLW = ''
    $script:BLU = ''; $script:MAG = ''; $script:CYN = ''; $script:GRY = ''
}

function Info  ($msg) { Write-Host "${script:CYN}ℹ${script:RST}  $msg" }
function Ok    ($msg) { Write-Host "${script:GRN}✓${script:RST}  $msg" }
function Warn  ($msg) { Write-Host "${script:YLW}⚠${script:RST}  $msg" }
function Err   ($msg) { Write-Host "${script:RED}✗${script:RST}  $msg" -ForegroundColor Red }

function Confirm-Action ($prompt) {
    if ($Yes) { return $true }
    Write-Host ""
    $answer = Read-Host "${script:BLD}${prompt}${script:RST} [y/N]"
    return $answer -match '^[Yy]$'
}

# ─── i18n ─────────────────────────────────────────────────────────────────────

function T ($key) {
    $zh = @{
        title            = 'OpenClaw 使用总结'
        days             = '相伴时光'
        sessions         = '会话总数'
        messages         = '消息总数'
        tokens           = 'Token 消耗'
        cost             = '估算费用'
        agents           = '智能体'
        skills           = 'Skills'
        channels         = '渠道'
        peak_hour        = '最活跃时段'
        fav_model        = '最爱模型'
        night_owl        = '夜猫子'
        early_bird       = '早起鸟'
        steady           = '稳定输出型'
        confirm_uninstall= '确认卸载 OpenClaw？'
        uninstall_done   = 'OpenClaw 已卸载完成，后会有期！'
        scanning         = '正在扫描本地数据...'
        no_data          = '未找到 OpenClaw 数据：'
        farewell_quote   = '次与 AI 的对话'
        farewell_power   = '你是一位超级用户。'
        farewell_thanks  = ''
        disclaimer       = '* 以上数据仅供参考娱乐，实际请以官方数据为准。'
        will_remove      = '以下内容将被删除：'
        kept             = '（已保留）'
        skip_dry         = '[预演模式] 未删除任何文件。'
        activity         = '24h 活跃度'
    }
    $en = @{
        title            = 'OpenClaw Usage Summary'
        days             = 'Days Together'
        sessions         = 'Conversations'
        messages         = 'Messages'
        tokens           = 'Tokens Used'
        cost             = 'Est. Cost'
        agents           = 'Agents'
        skills           = 'Skills'
        channels         = 'Channels'
        peak_hour        = 'Peak Hours'
        fav_model        = 'Favorite Model'
        night_owl        = 'Night Owl'
        early_bird       = 'Early Bird'
        steady           = 'Steady Worker'
        confirm_uninstall= 'Proceed with uninstall?'
        uninstall_done   = 'OpenClaw has been uninstalled. Farewell!'
        scanning         = 'Scanning local data...'
        no_data          = 'No OpenClaw data found at'
        farewell_quote   = 'late-night conversations with AI'
        farewell_power   = "You've been a power user."
        farewell_thanks  = ''
        disclaimer       = '* Data is approximate and for reference only.'
        will_remove      = 'The following will be removed:'
        kept             = '(kept)'
        skip_dry         = '[DRY RUN] No files were deleted.'
        activity         = '24h Activity'
    }
    $dict = if ($Lang -eq 'en') { $en } else { $zh }
    if ($dict.ContainsKey($key)) { return $dict[$key] }
    return $key
}

# ─── Utility ──────────────────────────────────────────────────────────────────

$script:OpenClawState = if ($env:OPENCLAW_STATE_DIR) { $env:OPENCLAW_STATE_DIR } else { Join-Path $env:USERPROFILE '.openclaw' }

function Validate-StateDir ($dir) {
    $resolved = try { (Resolve-Path $dir -ErrorAction Stop).Path } catch { $dir }

    $blocked = @(
        [System.IO.Path]::GetPathRoot($resolved)
        $env:USERPROFILE
        $env:SystemRoot
        $env:ProgramFiles
        ${env:ProgramFiles(x86)}
        $env:APPDATA
        $env:LOCALAPPDATA
        (Join-Path $env:USERPROFILE 'Desktop')
        (Join-Path $env:USERPROFILE 'Documents')
        (Join-Path $env:USERPROFILE 'Downloads')
        (Join-Path $env:USERPROFILE 'Pictures')
        (Join-Path $env:USERPROFILE 'Music')
        (Join-Path $env:USERPROFILE 'Videos')
    ) | Where-Object { $_ }

    foreach ($b in $blocked) {
        if ($resolved -eq $b) {
            Err "SAFETY: state dir '$dir' (resolved: '$resolved') matches blocked path '$b'. Aborting."
            exit 1
        }
    }

    $base = Split-Path $resolved -Leaf
    if ($base -notlike '.openclaw*') {
        Err "SAFETY: state dir basename '$base' does not start with '.openclaw'. Aborting."
        exit 1
    }
}

function Format-Num ($n) {
    if ($n -ge 1000000) { return '{0:F1}M' -f ($n / 1000000) }
    if ($n -ge 1000)    { return '{0:F1}K' -f ($n / 1000) }
    return [string]$n
}

function To-EpochS ($raw) {
    if (-not $raw -or $raw -eq 'null' -or $raw -eq '0' -or $raw -eq 0) { return 0 }
    if ($raw -is [long] -or $raw -is [int] -or $raw -match '^\d+$') {
        $n = [long]$raw
        if ($n -gt 10000000000) { return [math]::Floor($n / 1000) }
        return $n
    }
    try {
        $dt = [DateTimeOffset]::Parse($raw)
        return $dt.ToUnixTimeSeconds()
    } catch { return 0 }
}

function Format-EpochDate ($raw) {
    $s = To-EpochS $raw
    if ($s -eq 0) { return '?' }
    try {
        $dt = [DateTimeOffset]::FromUnixTimeSeconds($s).LocalDateTime
        return $dt.ToString('yyyy.MM.dd')
    } catch { return '?' }
}

function Has-Cmd ($name) {
    return $null -ne (Get-Command $name -ErrorAction SilentlyContinue)
}

function Read-JsonFile ($path) {
    if (-not (Test-Path $path)) { return $null }
    try { return Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $null }
}

# ─── Phase 1: Data Collection ────────────────────────────────────────────────

$script:Stat = @{
    FirstTS      = 0
    LastTS       = 0
    Days         = 0
    Sessions     = 0
    Messages     = 0
    InputTokens  = 0
    OutputTokens = 0
    TotalTokens  = 0
    EstCost      = '0.00'
    Agents       = 0
    Skills       = 0
    Channels     = ''
    FavModel     = ''
    PeakHour     = ''
    PeakLabel    = ''
    HourCounts   = @(0) * 24
}

function Collect-Data {
    Info (T 'scanning')
    Write-Host ""

    if (-not (Test-Path $script:OpenClawState)) {
        Warn "$(T 'no_data') $script:OpenClawState"
        return $false
    }

    Validate-StateDir $script:OpenClawState

    Collect-Agents
    Collect-Sessions
    Collect-TokensAndMessages
    Collect-Channels
    Collect-Models
    Collect-Skills
    Compute-PeakHours
    Estimate-Cost

    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if ($script:Stat.FirstTS -gt 0) {
        $script:Stat.Days = [math]::Max(1, [math]::Floor(($now - $script:Stat.FirstTS) / 86400))
    }
    if ($script:Stat.LastTS -eq 0) { $script:Stat.LastTS = $now }
    return $true
}

function Collect-Agents {
    $agentsDir = Join-Path $script:OpenClawState 'agents'
    if (Test-Path $agentsDir) {
        $script:Stat.Agents = @(Get-ChildItem $agentsDir -Directory -ErrorAction SilentlyContinue).Count
    }
}

function Collect-Sessions {
    $agentsDir = Join-Path $script:OpenClawState 'agents'
    if (-not (Test-Path $agentsDir)) { return }

    $earliest = 0; $latest = 0

    $jsonlFiles = Get-ChildItem $agentsDir -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.DirectoryName -like '*sessions*' -and $_.Name -like '*.jsonl*' }
    $script:Stat.Sessions = @($jsonlFiles).Count

    # Timestamps from sessions.json (updatedAt tracks last activity per route)
    $sessionFiles = Get-ChildItem $agentsDir -Recurse -Filter 'sessions.json' -ErrorAction SilentlyContinue
    foreach ($sf in $sessionFiles) {
        $json = Read-JsonFile $sf.FullName
        if (-not $json) { continue }
        foreach ($p in $json.PSObject.Properties) {
            $ua = $p.Value.updatedAt
            if ($ua) {
                $s = To-EpochS $ua
                if ($s -gt 0 -and ($earliest -eq 0 -or $s -lt $earliest)) { $earliest = $s }
                if ($s -gt $latest) { $latest = $s }
            }
        }
    }

    # Also check JSONL headers for earliest/latest timestamps
    foreach ($jf in ($jsonlFiles | Select-Object -First 50)) {
        $firstLine = Get-Content $jf.FullName -TotalCount 1 -ErrorAction SilentlyContinue
        if (-not $firstLine) { continue }
        try {
            $header = $firstLine | ConvertFrom-Json
            if ($header.timestamp) {
                $s = To-EpochS $header.timestamp
                if ($s -gt 0 -and ($earliest -eq 0 -or $s -lt $earliest)) { $earliest = $s }
                if ($s -gt $latest) { $latest = $s }
            }
        } catch {}
    }

    $script:Stat.FirstTS = $earliest
    $script:Stat.LastTS  = $latest
}

function Collect-TokensAndMessages {
    $agentsDir = Join-Path $script:OpenClawState 'agents'
    if (-not (Test-Path $agentsDir)) { return }

    $totalIn = 0; $totalOut = 0; $totalAll = 0; $msgCount = 0
    $cliTokens = $false

    # Prefer CLI for token totals — sessions.json counters reset on each session reset
    if (Has-Cmd 'openclaw') {
        try {
            $usageOut = & openclaw status --usage --json 2>$null | ConvertFrom-Json
            if ($usageOut) {
                $cIn  = if ($usageOut.inputTokens) { $usageOut.inputTokens } elseif ($usageOut.totalInputTokens) { $usageOut.totalInputTokens } else { 0 }
                $cOut = if ($usageOut.outputTokens) { $usageOut.outputTokens } elseif ($usageOut.totalOutputTokens) { $usageOut.totalOutputTokens } else { 0 }
                $cTot = if ($usageOut.totalTokens) { $usageOut.totalTokens } else { 0 }
                if ($cTot -gt 0 -or $cIn -gt 0) {
                    $totalIn = [long]$cIn; $totalOut = [long]$cOut; $totalAll = [long]$cTot
                    $cliTokens = $true
                }
            }
        } catch {}
    }

    # Fallback: sum from sessions.json (only reflects current active sessions)
    if (-not $cliTokens) {
        $sessionFiles = Get-ChildItem $agentsDir -Recurse -Filter 'sessions.json' -ErrorAction SilentlyContinue
        foreach ($sf in $sessionFiles) {
            $json = Read-JsonFile $sf.FullName
            if (-not $json) { continue }
            foreach ($p in $json.PSObject.Properties) {
                $totalIn  += [long]($p.Value.inputTokens  -as [long])
                $totalOut += [long]($p.Value.outputTokens  -as [long])
                $totalAll += [long]($p.Value.totalTokens   -as [long])
            }
        }
    }

    $jsonlFiles = Get-ChildItem $agentsDir -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.DirectoryName -like '*sessions*' -and $_.Name -like '*.jsonl*' } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 200
    foreach ($jf in $jsonlFiles) {
        $lines = Get-Content $jf.FullName -TotalCount 5000 -ErrorAction SilentlyContinue
        if ($lines) {
            $msgCount += @($lines | Where-Object { $_ -match '"type"\s*:\s*"message"' }).Count
        }
    }

    $script:Stat.InputTokens  = $totalIn
    $script:Stat.OutputTokens = $totalOut
    $script:Stat.TotalTokens  = $totalAll
    $script:Stat.Messages     = $msgCount

    if ($script:Stat.TotalTokens -eq 0 -and $script:Stat.InputTokens -gt 0) {
        $script:Stat.TotalTokens = $script:Stat.InputTokens + $script:Stat.OutputTokens
    }
}

function Collect-Channels {
    $cfg = Join-Path $script:OpenClawState 'openclaw.json'
    if (-not (Test-Path $cfg)) { return }
    $json = Read-JsonFile $cfg
    if ($json -and $json.channels) {
        $names = $json.channels.PSObject.Properties.Name -join ', '
        if ($names) { $script:Stat.Channels = $names }
    }
}

function Collect-Models {
    $agentsDir = Join-Path $script:OpenClawState 'agents'
    if (-not (Test-Path $agentsDir)) { return }

    $models = @()
    $authFiles = Get-ChildItem $agentsDir -Recurse -Filter 'auth-profiles.json' -ErrorAction SilentlyContinue
    foreach ($af in $authFiles) {
        $json = Read-JsonFile $af.FullName
        if (-not $json) { continue }
        foreach ($p in $json.PSObject.Properties) {
            if ($p.Value.provider) { $models += $p.Value.provider }
            if ($p.Value.modelId)  { $models += $p.Value.modelId }
        }
    }

    if ($models.Count -eq 0) {
        $cfg = Join-Path $script:OpenClawState 'openclaw.json'
        $json = Read-JsonFile $cfg
        if ($json -and $json.providers) {
            $first = $json.providers.PSObject.Properties.Name | Select-Object -First 1
            if ($first) { $models += $first }
        }
    }

    if ($models.Count -gt 0) {
        $script:Stat.FavModel = ($models | Group-Object | Sort-Object Count -Descending | Select-Object -First 1).Name
    }
}

function Collect-Skills {
    $skillsDir = Join-Path $script:OpenClawState 'skills'
    if (Test-Path $skillsDir) {
        $script:Stat.Skills = @(Get-ChildItem $skillsDir -Directory -ErrorAction SilentlyContinue).Count
    }
}

function Compute-PeakHours {
    $hours = @(0) * 24
    $agentsDir = Join-Path $script:OpenClawState 'agents'
    if (-not (Test-Path $agentsDir)) { return }

    $jsonlFiles = Get-ChildItem $agentsDir -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.DirectoryName -like '*sessions*' -and $_.Name -like '*.jsonl*' } |
        Select-Object -First 30
    foreach ($jf in $jsonlFiles) {
        $lines = Get-Content $jf.FullName -TotalCount 200 -ErrorAction SilentlyContinue
        foreach ($line in $lines) {
            if ($line -match '"timestamp"\s*:\s*"?([^",}]+)') {
                $raw = $Matches[1].Trim()
                $s = To-EpochS $raw
                if ($s -gt 0) {
                    try {
                        $h = [DateTimeOffset]::FromUnixTimeSeconds($s).LocalDateTime.Hour
                        $hours[$h]++
                    } catch {}
                }
            }
        }
    }

    $script:Stat.HourCounts = $hours
    $maxCount = 0; $maxHour = 0
    for ($i = 0; $i -lt 24; $i++) {
        if ($hours[$i] -gt $maxCount) { $maxCount = $hours[$i]; $maxHour = $i }
    }
    if ($maxCount -gt 0) {
        $endHour = ($maxHour + 3) % 24
        $script:Stat.PeakHour = '{0:D2}:00 ~ {1:D2}:00' -f $maxHour, $endHour

        if ($maxHour -ge 22 -or $maxHour -le 3) {
            $script:Stat.PeakLabel = T 'night_owl'
        } elseif ($maxHour -ge 5 -and $maxHour -le 8) {
            $script:Stat.PeakLabel = T 'early_bird'
        } else {
            $script:Stat.PeakLabel = T 'steady'
        }
    }
}

function Estimate-Cost {
    if (Has-Cmd 'openclaw') {
        try {
            $out = & openclaw status --usage --json 2>$null | ConvertFrom-Json
            if ($out.totalCost) { $script:Stat.EstCost = $out.totalCost; return }
        } catch {}
    }

    if ($script:Stat.InputTokens -gt 0 -or $script:Stat.OutputTokens -gt 0) {
        $script:Stat.EstCost = '{0:F2}' -f (($script:Stat.InputTokens * 3 + $script:Stat.OutputTokens * 15) / 1000000 * 7)
    } elseif ($script:Stat.TotalTokens -gt 0) {
        $script:Stat.EstCost = '{0:F2}' -f ($script:Stat.TotalTokens * 8 / 1000000 * 7)
    }
}

# ─── Phase 2: Wrapped Renderer ───────────────────────────────────────────────

$script:RULER      = '═' * 48
$script:THIN_RULER = '─' * 48

function Get-DisplayWidth ($text) {
    $w = 0
    foreach ($c in $text.ToCharArray()) {
        $cp = [int]$c
        if (($cp -ge 0x1100 -and $cp -le 0x115F) -or
            ($cp -ge 0x2E80 -and $cp -le 0x9FFF) -or
            ($cp -ge 0xAC00 -and $cp -le 0xD7AF) -or
            ($cp -ge 0xF900 -and $cp -le 0xFAFF) -or
            ($cp -ge 0xFE10 -and $cp -le 0xFE6F) -or
            ($cp -ge 0xFF01 -and $cp -le 0xFF60) -or
            ($cp -ge 0xFFE0 -and $cp -le 0xFFE6)) {
            $w += 2
        } else {
            $w += 1
        }
    }
    return $w
}

function Print-Stat ($emoji, $label, $value) {
    $dw = Get-DisplayWidth $label
    $pad = [math]::Max(0, 14 - $dw)
    Write-Host ("  {0}  {1}{2}  {3}" -f $emoji, $label, (' ' * $pad), $value)
}

function Render-Sparkline {
    $bars = '▁','▂','▃','▄','▅','▆','▇','█'
    $max = [math]::Max(1, ($script:Stat.HourCounts | Measure-Object -Maximum).Maximum)
    $line = ''
    for ($i = 0; $i -lt 24; $i++) {
        $idx = [math]::Floor($script:Stat.HourCounts[$i] * 7 / $max)
        $line += $bars[$idx]
    }
    return $line
}

function Render-Wrapped {
    Write-Host ""

    $firstDate = if ($script:Stat.FirstTS -gt 0) { Format-EpochDate $script:Stat.FirstTS } else { '?' }
    $today = (Get-Date).ToString('yyyy.MM.dd')

    # Title
    Write-Host "  ${script:BLD}${script:MAG}${script:RULER}${script:RST}"
    Write-Host ""
    Write-Host "            ${script:BLD}${script:MAG}🐾  $(T 'title')${script:RST}"
    Write-Host ""
    Write-Host "  ${script:DIM}${script:THIN_RULER}${script:RST}"
    Write-Host ""

    # Stats
    $ud = if ($Lang -eq 'en') { ' days' } else { ' 天' }
    $us = if ($Lang -eq 'en') { '' } else { ' 次' }
    $um = if ($Lang -eq 'en') { '' } else { ' 条' }
    $ua = if ($Lang -eq 'en') { '' } else { ' 个' }

    $tokensFmt = Format-Num $script:Stat.TotalTokens

    Print-Stat "${script:CYN}📅${script:RST}" (T 'days')     "${script:BLD}$($script:Stat.Days)${ud}${script:RST}（${firstDate} ~ ${today}）"
    Print-Stat "${script:CYN}💬${script:RST}" (T 'sessions') "${script:BLD}$($script:Stat.Sessions)${us}${script:RST}"
    Print-Stat "${script:CYN}📨${script:RST}" (T 'messages') "${script:BLD}$($script:Stat.Messages)${um}${script:RST}"
    Print-Stat "${script:CYN}🧠${script:RST}" (T 'tokens')   "${script:BLD}${tokensFmt} tokens${script:RST}"
    Print-Stat "${script:CYN}💰${script:RST}" (T 'cost')     "${script:BLD}≈ ¥$($script:Stat.EstCost)${script:RST}"
    Print-Stat "${script:CYN}🤖${script:RST}" (T 'agents')   "${script:BLD}$($script:Stat.Agents)${ua}${script:RST}"
    Print-Stat "${script:CYN}🔧${script:RST}" (T 'skills')   "${script:BLD}$($script:Stat.Skills)${ua}${script:RST}"

    if ($script:Stat.Channels) {
        Print-Stat "${script:CYN}📱${script:RST}" (T 'channels') "${script:BLD}$($script:Stat.Channels)${script:RST}"
    }
    if ($script:Stat.PeakHour) {
        Print-Stat "${script:CYN}🌙${script:RST}" (T 'peak_hour') "${script:BLD}$($script:Stat.PeakHour)${script:RST}（$($script:Stat.PeakLabel)）"
    }
    if ($script:Stat.FavModel) {
        Print-Stat "${script:CYN}🏆${script:RST}" (T 'fav_model') "${script:BLD}$($script:Stat.FavModel)${script:RST}"
    }

    # Sparkline
    $hasActivity = ($script:Stat.HourCounts | Where-Object { $_ -gt 0 }).Count -gt 0
    if ($hasActivity) {
        Write-Host ""
        Write-Host "  ${script:GRY}── $(T 'activity') ──${script:RST}"
        Write-Host "  ${script:GRY}$(Render-Sparkline)${script:RST}"
        Write-Host "  ${script:DIM}0     6     12    18  23${script:RST}"
    }

    # Farewell
    Write-Host ""
    Write-Host "  ${script:DIM}${script:THIN_RULER}${script:RST}"
    Write-Host ""

    if ($Lang -eq 'en') {
        $quote = "  `"Your $($script:Stat.Sessions) $(T 'farewell_quote').`""
    } else {
        $quote = "  `"你与 AI 的 $($script:Stat.Sessions) 次会话。`""
    }
    Write-Host "  ${script:YLW}${script:BLD}${quote}${script:RST}"
    Write-Host "  ${script:YLW}$(T 'farewell_power')${script:RST}"
    Write-Host ""
    Write-Host "  ${script:DIM}$(T 'disclaimer')${script:RST}"

    Write-Host ""
    Write-Host "  ${script:BLD}${script:MAG}${script:RULER}${script:RST}"
    Write-Host ""

    Generate-ShareText
}

function Generate-ShareText {
    $firstDate = if ($script:Stat.FirstTS -gt 0) { Format-EpochDate $script:Stat.FirstTS } else { '?' }
    $today = (Get-Date).ToString('yyyy.MM.dd')
    $tokensFmt = Format-Num $script:Stat.TotalTokens

    if ($Lang -eq 'en') {
        $text = @"
🐾 My OpenClaw Journey · Wrapped

📅 $($script:Stat.Days) days together ($firstDate ~ $today)
💬 $($script:Stat.Sessions) conversations | 📨 $($script:Stat.Messages) messages
🧠 $tokensFmt tokens | 💰 ≈ ¥$($script:Stat.EstCost)
🤖 $($script:Stat.Agents) agents | 🔧 $($script:Stat.Skills) skills
"@
        if ($script:Stat.PeakHour) { $text += "`n🌙 Peak: $($script:Stat.PeakHour) ($($script:Stat.PeakLabel))" }
        if ($script:Stat.FavModel) { $text += "`n🏆 Favorite: $($script:Stat.FavModel)" }
        $text += "`n`nFarewell, OpenClaw! #ClawfatherWrapped #OpenClaw"
    } else {
        $text = @"
🐾 我的 OpenClaw 之旅 · Wrapped

📅 相伴 $($script:Stat.Days) 天（$firstDate ~ $today）
💬 $($script:Stat.Sessions) 次对话 | 📨 $($script:Stat.Messages) 条消息
🧠 $tokensFmt tokens | 💰 ≈ ¥$($script:Stat.EstCost)
🤖 $($script:Stat.Agents) 个智能体 | 🔧 $($script:Stat.Skills) 个 Skills
"@
        if ($script:Stat.PeakHour) { $text += "`n🌙 最活跃: $($script:Stat.PeakHour)（$($script:Stat.PeakLabel)）" }
        if ($script:Stat.FavModel) { $text += "`n🏆 最爱: $($script:Stat.FavModel)" }
        $text += "`n`n后会有期，OpenClaw！#ClawfatherWrapped #OpenClaw"
    }

    if ($DryRun) { return }

    $desktop = [Environment]::GetFolderPath('Desktop')
    if ($desktop -and (Test-Path $desktop)) {
        $reportFile = Join-Path $desktop 'openclaw-wrapped.txt'
        if (Test-Path $reportFile) {
            $ts = (Get-Date).ToString('yyyyMMddHHmmss')
            $reportFile = Join-Path $desktop "openclaw-wrapped-$ts.txt"
        }
        $text | Out-File -FilePath $reportFile -Encoding UTF8 -Force
        Ok "📄 $reportFile"
    }
}

# ─── Phase 3: Uninstall Engine ────────────────────────────────────────────────

$script:ItemsToRemove = @()

function Survey-Removals {
    $script:ItemsToRemove = @()

    if (Has-Cmd 'openclaw') {
        $clawPath = (Get-Command openclaw -ErrorAction SilentlyContinue).Source
        $script:ItemsToRemove += @{ Kind = 'cli'; Desc = "openclaw CLI ($clawPath)" }
    }

    if (Test-Path $script:OpenClawState) {
        if (-not $KeepConfig) {
            $script:ItemsToRemove += @{ Kind = 'state'; Desc = $script:OpenClawState }
        } else {
            $script:ItemsToRemove += @{ Kind = 'state_partial'; Desc = "$($script:OpenClawState)\agents (sessions only)" }
        }
    }

    $workspace = Join-Path $script:OpenClawState 'workspace'
    if ((Test-Path $workspace) -and -not $KeepConfig) {
        $script:ItemsToRemove += @{ Kind = 'workspace'; Desc = $workspace }
    }

    # Scheduled task
    try {
        $task = Get-ScheduledTask -TaskName 'OpenClaw Gateway' -ErrorAction SilentlyContinue
        if ($task) {
            $script:ItemsToRemove += @{ Kind = 'schtask'; Desc = 'OpenClaw Gateway (Scheduled Task)' }
        }
    } catch {}

    $gatewayCmdPath = Join-Path $script:OpenClawState 'gateway.cmd'
    if (Test-Path $gatewayCmdPath) {
        $script:ItemsToRemove += @{ Kind = 'gateway_cmd'; Desc = $gatewayCmdPath }
    }

    # Profile directories
    Get-ChildItem $env:USERPROFILE -Directory -Filter '.openclaw-*' -ErrorAction SilentlyContinue | ForEach-Object {
        $resolved = try { (Resolve-Path $_.FullName -ErrorAction Stop).Path } catch { $_.FullName }
        $base = Split-Path $resolved -Leaf
        if ($base -notlike '.openclaw*') { return }
        if ($resolved -eq $env:USERPROFILE) { return }
        $script:ItemsToRemove += @{ Kind = 'profile'; Desc = $resolved }
    }
}

function Print-RemovalList {
    Write-Host ""
    Write-Host "${script:BLD}$(T 'will_remove')${script:RST}"
    Write-Host ""
    foreach ($item in $script:ItemsToRemove) {
        $icon = "${script:RED}●${script:RST}"
        if ($item.Kind -eq 'state_partial') { $icon = "${script:YLW}●${script:RST}" }
        $label = switch ($item.Kind) {
            'cli'           { 'CLI' }
            'state'         { 'State' }
            'state_partial' { 'Sessions' }
            'workspace'     { 'Workspace' }
            'schtask'       { 'Service' }
            'gateway_cmd'   { 'Script' }
            'profile'       { 'Profile' }
            default         { $item.Kind }
        }
        Write-Host "  $icon ${label}: $($item.Desc)"
    }

    if ($KeepConfig) {
        Write-Host ""
        Write-Host "  ${script:GRN}●${script:RST} Config $(T 'kept')"
    }
    Write-Host ""
}

function Do-Uninstall {
    $total = $script:ItemsToRemove.Count
    $current = 0

    foreach ($item in $script:ItemsToRemove) {
        $current++
        Write-Host "  [$current/$total] $($item.Kind)..."

        switch ($item.Kind) {
            'cli' { Uninstall-Cli }
            'state' {
                Remove-Item $script:OpenClawState -Recurse -Force -ErrorAction SilentlyContinue
                Ok "Removed $($script:OpenClawState)"
            }
            'state_partial' {
                Get-ChildItem (Join-Path $script:OpenClawState 'agents') -Recurse -Include '*.jsonl','sessions.json' -ErrorAction SilentlyContinue |
                    Remove-Item -Force -ErrorAction SilentlyContinue
                Ok "Cleaned session data"
            }
            'workspace' {
                Remove-Item $item.Desc -Recurse -Force -ErrorAction SilentlyContinue
                Ok "Removed workspace"
            }
            'schtask' {
                try { Unregister-ScheduledTask -TaskName 'OpenClaw Gateway' -Confirm:$false -ErrorAction SilentlyContinue } catch {}
                try { schtasks /Delete /F /TN 'OpenClaw Gateway' 2>$null | Out-Null } catch {}
                Ok "Removed scheduled task"
            }
            'gateway_cmd' {
                Remove-Item $item.Desc -Force -ErrorAction SilentlyContinue
                Ok "Removed $($item.Desc)"
            }
            'profile' {
                Remove-Item $item.Desc -Recurse -Force -ErrorAction SilentlyContinue
                Ok "Removed $($item.Desc)"
            }
        }
    }
}

function Uninstall-Cli {
    if (Has-Cmd 'openclaw') {
        Info "Running official uninstall..."
        try { & openclaw gateway stop 2>$null | Out-Null } catch {}
        Ok "Gateway stopped"
        try { & openclaw gateway uninstall 2>$null | Out-Null } catch {}
        Ok "Gateway service removed"
    }

    if (Has-Cmd 'npm')  { try { & npm rm -g openclaw 2>$null | Out-Null } catch {} }
    if (Has-Cmd 'pnpm') { try { & pnpm remove -g openclaw 2>$null | Out-Null } catch {} }
    if (Has-Cmd 'bun')  { try { & bun remove -g openclaw 2>$null | Out-Null } catch {} }

    Ok "CLI uninstalled"
}

function Verify-Uninstall {
    Write-Host ""
    $clean = $true

    if (Has-Cmd 'openclaw') {
        Warn "openclaw still on PATH: $((Get-Command openclaw).Source)"
        $clean = $false
    }

    # Second-pass cleanup for directories recreated during uninstall
    if ((Test-Path $script:OpenClawState) -and -not $KeepConfig) {
        Remove-Item $script:OpenClawState -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ((Test-Path $script:OpenClawState) -and -not $KeepConfig) {
        Warn "$($script:OpenClawState) still exists"
        $clean = $false
    }

    if ($clean) {
        Write-Host ""
        Write-Host "  ${script:BLD}${script:GRN}╭──────────────────────────────────────────╮${script:RST}"
        Write-Host "  ${script:BLD}${script:GRN}│                                          │${script:RST}"
        Write-Host "  ${script:BLD}${script:GRN}│    🐾  $(T 'uninstall_done')${script:RST}"
        Write-Host "  ${script:BLD}${script:GRN}│                                          │${script:RST}"
        Write-Host "  ${script:BLD}${script:GRN}╰──────────────────────────────────────────╯${script:RST}"
        Write-Host ""
    }
}

# ─── Main ─────────────────────────────────────────────────────────────────────

function Main {
    Write-Host ""
    Write-Host "  ${script:BLD}${script:MAG}🐾 Clawfather Uninstaller v${script:VERSION}${script:RST}"
    Write-Host "  ${script:GRY}${script:THIN_RULER}${script:RST}"
    Write-Host ""

    $hasData = Collect-Data
    if ($hasData) { Render-Wrapped }

    if ($WrappedOnly) { return }

    Survey-Removals

    if ($script:ItemsToRemove.Count -eq 0) {
        Ok "No OpenClaw components found to clean up."
        return
    }

    Print-RemovalList

    if ($DryRun) {
        Info (T 'skip_dry')
        return
    }

    if (-not (Confirm-Action (T 'confirm_uninstall'))) {
        Info "Cancelled."
        return
    }

    Write-Host ""
    Do-Uninstall
    Verify-Uninstall
}

Main
