param(
    [string]$RakutenAppId = "",
    [string]$RakutenAffiliateId = "",
    [string]$RemoteVideoPath = "/sdcard/Movies/play_demo.mp4",
    [int]$VideoBitRate = 8000000,
    [switch]$DemoMode,
    # 未指定時は起動時に 1=debug / 2=release を選択。Play 用スクショは release 推奨（DEBUG バナー非表示）。
    [ValidateSet("debug", "release", "")]
    [string]$BuildMode = "",
    # 追加の --dart-define。KEY=VALUE または --dart-define=KEY=VALUE。既存キーは二重付与しない。
    # 複数: -DartDefine "A=1","B=2" または -DartDefine A=1,B=2（PS 7.6 は同一パラメータの繰り返し不可）
    [string[]]$DartDefine = @()
)

$ErrorActionPreference = "Stop"

try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
} catch {}
$OutputEncoding = [System.Text.UTF8Encoding]::new()

# PSReadLine が複数端末で同一履歴ファイルを掴むと「being used by another process」になる。
# このスクリプト経由のセッションは PID 別ファイルに逃がす（未導入・古い環境では無視）。
try {
    if (Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue) {
        $histDir = Join-Path $env:LOCALAPPDATA "room_manager2_psreadline"
        if (-not (Test-Path $histDir)) {
            New-Item -ItemType Directory -Path $histDir -Force | Out-Null
        }
        Set-PSReadLineOption -HistorySavePath (Join-Path $histDir "history_$PID.txt") -ErrorAction SilentlyContinue
    }
} catch {}

$CurrentDir = (Get-Location).Path
$FolderName = Split-Path $CurrentDir -Leaf
$SafeAppName = ($FolderName -replace '[\\/:*?"<>| ]', '_')
$LocalSaveDir = Join-Path $CurrentDir "recordings"
$CommandFile = Join-Path $LocalSaveDir "recording_command.txt"
$LockFile = Join-Path $LocalSaveDir "recording_session.lock"
$ControllerScriptPath = Join-Path $CurrentDir "recording_controller.ps1"

# スクショ保存フォルダ内の統合ログ（terminal_output_*.txt）へ追記。未初期化時はコンソールのみ。
$script:TerminalOutputLogPath = $null

function Write-TerminalLog {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Message,
        [Parameter()]
        $ForegroundColor = $null
    )

    if ($null -ne $ForegroundColor) {
        Write-Host $Message -ForegroundColor ([System.ConsoleColor]$ForegroundColor)
    }
    else {
        Write-Host $Message
    }

    $logPath = $script:TerminalOutputLogPath
    if ([string]::IsNullOrWhiteSpace($logPath)) {
        return
    }

    try {
        $parent = Split-Path -Parent $logPath
        if (-not (Test-Path -LiteralPath $parent)) {
            return
        }

        [System.IO.File]::AppendAllText(
            $logPath,
            $Message + [Environment]::NewLine,
            [System.Text.UTF8Encoding]::new($false))
    }
    catch {
        # ログ追記失敗で録画・スクショ後処理を止めない
    }
}

Set-Alias -Name Write-SessionLog -Value Write-TerminalLog -Scope Script -ErrorAction SilentlyContinue

# Write-Section と対になる見出しをログファイルだけへ書く（コンソールは二重表示にしない）
function Write-TerminalLogSection {
    param([Parameter(Mandatory = $true)][string]$Message)

    $logPath = $script:TerminalOutputLogPath
    if ([string]::IsNullOrWhiteSpace($logPath)) {
        return
    }

    try {
        $nl = [Environment]::NewLine
        $block = "$nl====================================================$nl$Message$nl====================================================$nl"
        [System.IO.File]::AppendAllText($logPath, $block, [System.Text.UTF8Encoding]::new($false))
    }
    catch {
    }
}

function Write-Section {
    param([string]$Message)
    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "====================================================" -ForegroundColor Cyan
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Test-CommandExists {
    param([string]$CommandName)
    $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue
    return $null -ne $cmd
}

function Get-FlutterCommandPath {
    $cmd = Get-Command flutter -ErrorAction SilentlyContinue
    if ($null -eq $cmd) {
        throw "flutter command not found. Check PATH."
    }

    if ($cmd.Source) { return $cmd.Source }
    if ($cmd.Path)   { return $cmd.Path }

    throw "Could not resolve flutter command path."
}

function Get-PwshCommandPath {
    $cmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($null -eq $cmd) {
        throw "pwsh not found. Install PowerShell 7 and confirm it is on PATH."
    }

    if ($cmd.Source) { return $cmd.Source }
    if ($cmd.Path)   { return $cmd.Path }

    throw "Could not resolve pwsh command path."
}

function Get-ConnectedDevices {
    $raw = adb devices
    $lines = $raw | Where-Object {
        $_ -and
        $_ -notmatch "^List of devices attached" -and
        $_.Trim() -ne ""
    }

    $devices = @()

    foreach ($line in $lines) {
        $normalized = ($line -replace "`t", " ").Trim()
        $parts = $normalized -split "\s+"

        if ($parts.Count -ge 2) {
            $deviceId = $parts[0]
            $state = $parts[1]

            if ($state -eq "device") {
                $model = ""
                try {
                    $model = (adb -s $deviceId shell getprop ro.product.model 2>$null | Out-String).Trim()
                } catch {}

                $manufacturer = ""
                try {
                    $manufacturer = (adb -s $deviceId shell getprop ro.product.manufacturer 2>$null | Out-String).Trim()
                } catch {}

                $devices += [PSCustomObject]@{
                    Id           = $deviceId
                    State        = $state
                    Manufacturer = $manufacturer
                    Model        = $model
                }
            }
        }
    }

    return $devices
}

function Select-BuildMode {
    if ($BuildMode -eq "debug" -or $BuildMode -eq "release") {
        $label = if ($BuildMode -eq "release") { "Release (no DEBUG banner)" } else { "Debug (hot reload)" }
        Write-Host "Build mode (from parameter): $label" -ForegroundColor Green
        return $BuildMode
    }

    Write-Section "Select build mode"
    Write-Host "[1] Debug   - hot reload (R), DEBUG banner shown" -ForegroundColor Cyan
    Write-Host "[2] Release - for Play Store screenshots (no DEBUG banner)" -ForegroundColor Cyan
    Write-Host ""

    while ($true) {
        $inputValue = Read-Host "Enter number (1 or 2)"
        switch ($inputValue.Trim()) {
            "1" { return "debug" }
            "2" { return "release" }
            default { Write-Host "Invalid number. Enter 1 or 2." -ForegroundColor Yellow }
        }
    }
}

function Select-AndroidDevice {
    $devices = Get-ConnectedDevices

    if (-not $devices -or $devices.Count -eq 0) {
        throw "No adb device found."
    }

    if ($devices.Count -eq 1) {
        $d = $devices[0]
        Write-Host "Single device detected: $($d.Id) [$($d.Manufacturer) $($d.Model)]" -ForegroundColor Green
        return $d
    }

    Write-Section "Select device"
    for ($i = 0; $i -lt $devices.Count; $i++) {
        $d = $devices[$i]
        Write-Host ("[{0}] {1}  {2} {3}" -f ($i + 1), $d.Id, $d.Manufacturer, $d.Model)
    }

    while ($true) {
        $inputValue = Read-Host "Enter number"
        $num = 0
        if ([int]::TryParse($inputValue, [ref]$num)) {
            if ($num -ge 1 -and $num -le $devices.Count) {
                return $devices[$num - 1]
            }
        }
        Write-Host "Invalid number." -ForegroundColor Yellow
    }
}

function Stop-AndroidScreenRecord {
    param([string]$DeviceId)

    Write-Section "Stopping screenrecord"
    Write-TerminalLogSection "Stopping screenrecord"

    try {
        adb -s $DeviceId shell "pkill -INT screenrecord" | Out-Host
        Start-Sleep -Seconds 2
    } catch {}

    try {
        $pidText = adb -s $DeviceId shell "pidof screenrecord" 2>$null
        if ($pidText) {
            $pids = ($pidText -replace "`r","" -replace "`n","").Trim().Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)
            foreach ($pid in $pids) {
                adb -s $DeviceId shell "kill -2 $pid" | Out-Host
            }
            Start-Sleep -Seconds 2
        }
    } catch {}

    # プロセスが無いとき killall が stderr に出すので、存在するときだけ送る
    try {
        $still = (adb -s $DeviceId shell "pidof screenrecord" 2>$null | Out-String).Trim()
        if ($still) {
            adb -s $DeviceId shell "sh -c 'killall -2 screenrecord 2>/dev/null; exit 0'" | Out-Null
            Start-Sleep -Seconds 2
        }
    } catch {}

    Write-TerminalLog "[SCREENRECORD] Stop/signaling sequence finished (see recorder stdout/stderr logs under recordings\ for adb details)."
}

function Test-RemoteFileExists {
    param(
        [string]$DeviceId,
        [string]$RemotePath
    )

    $result = adb -s $DeviceId shell "if [ -f '$RemotePath' ]; then echo EXISTS; else echo NOT_FOUND; fi"
    $text = ($result | Out-String).Trim()
    return $text -match "EXISTS"
}

function Get-NextScreenshotPath {
    param(
        [string]$ScreenshotDirPath,
        [string]$AppName
    )

    Ensure-Directory -Path $ScreenshotDirPath

    $existing = Get-ChildItem -Path $ScreenshotDirPath -Filter "${AppName}_shot_*.png" -File -ErrorAction SilentlyContinue

    $maxNo = 0
    foreach ($file in $existing) {
        if ($file.BaseName -match ("^" + [regex]::Escape($AppName) + "_shot_(\d+)$")) {
            $num = [int]$matches[1]
            if ($num -gt $maxNo) {
                $maxNo = $num
            }
        }
    }

    $nextNo = $maxNo + 1
    $fileName = "{0}_shot_{1:D3}.png" -f $AppName, $nextNo
    return Join-Path $ScreenshotDirPath $fileName
}

function Save-Screenshot {
    param(
        [string]$DeviceId,
        [string]$ScreenshotPath
    )

    Write-Host ""
    Write-Host "Saving screenshot..." -ForegroundColor Yellow

    $tempShotPath = Join-Path ([System.IO.Path]::GetTempPath()) ("adb_screencap_{0}.png" -f ([guid]::NewGuid().ToString("N")))

    try {
        $null = Start-Process `
            -FilePath "adb" `
            -ArgumentList @("-s", $DeviceId, "exec-out", "screencap", "-p") `
            -RedirectStandardOutput $tempShotPath `
            -NoNewWindow `
            -PassThru `
            -Wait

        if (-not (Test-Path $tempShotPath)) {
            throw "Temporary screenshot file was not created."
        }

        Move-Item -Path $tempShotPath -Destination $ScreenshotPath -Force
        Write-Host "Saved: $ScreenshotPath" -ForegroundColor Green
        Write-Host ""
    }
    catch {
        if (Test-Path $tempShotPath) {
            Remove-Item $tempShotPath -Force -ErrorAction SilentlyContinue
        }
        throw
    }
}

function Show-Help {
    param([bool]$ReleaseMode = $false)

    Write-Host ""
    Write-Host "Controller window commands:" -ForegroundColor Cyan
    Write-Host "  S : save screenshot" -ForegroundColor Cyan
    if (-not $ReleaseMode) {
        Write-Host "  R : flutter hot reload" -ForegroundColor Cyan
    }
    Write-Host "  Q : stop flutter and collect video" -ForegroundColor Cyan
    Write-Host "  H : show help" -ForegroundColor Cyan
    if ($ReleaseMode) {
        Write-Host ""
        Write-Host "  (Release mode: hot reload is not available)" -ForegroundColor DarkGray
    }
    Write-Host ""
}

function Get-DartDefineKeyFromEntry {
    param([string]$Entry)

    $s = $Entry.Trim()
    if ([string]::IsNullOrWhiteSpace($s)) {
        return $null
    }

    if ($s -match '^--dart-define=(.+)$') {
        $s = $matches[1]
    }

    $eqIdx = $s.IndexOf('=')
    if ($eqIdx -lt 1) {
        return $null
    }

    return $s.Substring(0, $eqIdx)
}

function Test-SensitiveDartDefineKey {
    param([string]$Key)

    if ([string]::IsNullOrWhiteSpace($Key)) {
        return $false
    }

    $k = $Key.Trim()
    $exactSensitive = @(
        'AI_GATEWAY_APP_KEY',
        'RAKUTEN_APP_ID',
        'RAKUTEN_AFFILIATE_ID'
    )
    foreach ($name in $exactSensitive) {
        if ($k -eq $name) {
            return $true
        }
    }

    if ($k -match '(?i)(API[_-]?KEY|APP[_-]?KEY|SECRET|TOKEN|PASSWORD)$') {
        return $true
    }

    return $false
}

function ConvertTo-RedactedDartDefineEntry {
    param([string]$Entry)

    $trimmed = $Entry.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        return $trimmed
    }

    $key = Get-DartDefineKeyFromEntry -Entry $trimmed
    if (-not $key) {
        return $trimmed
    }

    if (Test-SensitiveDartDefineKey -Key $key) {
        return "$key=[redacted]"
    }

    return $trimmed
}

function ConvertTo-RedactedDartDefineArg {
    param([string]$Entry)

    $arg = ConvertTo-DartDefineArg -Entry $Entry
    if (-not $arg) {
        return $null
    }

    $key = Get-DartDefineKeyFromEntry -Entry $arg
    if (Test-SensitiveDartDefineKey -Key $key) {
        return "--dart-define=$key=[redacted]"
    }

    return $arg
}

function Get-RedactedFlutterLaunchCommand {
    param(
        [string]$StartFile,
        [string[]]$StartArgs
    )

    $redactedArgs = foreach ($arg in $StartArgs) {
        if ($arg -match '^--dart-define=') {
            ConvertTo-RedactedDartDefineArg -Entry $arg
        }
        else {
            $arg
        }
    }

    return "$StartFile $($redactedArgs -join ' ')"
}

function ConvertTo-DartDefineArg {
    param([string]$Entry)

    $trimmed = $Entry.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        return $null
    }

    if ($trimmed -match '^--dart-define=') {
        return $trimmed
    }

    return "--dart-define=$trimmed"
}

function Expand-DartDefineInputs {
    param([string[]]$Inputs)

    $expanded = [System.Collections.Generic.List[string]]::new()
    if (-not $Inputs) {
        return $expanded
    }

    foreach ($item in $Inputs) {
        if ([string]::IsNullOrWhiteSpace($item)) {
            continue
        }

        $trimmed = $item.Trim()
        # -File 起動時は -DartDefine A=1,B=2 が 1 要素になるためカンマで分割する
        if ($trimmed -notmatch '^--dart-define=' -and $trimmed.Contains(',') -and $trimmed.Contains('=')) {
            foreach ($part in $trimmed.Split(',')) {
                $piece = $part.Trim()
                if ($piece) {
                    $expanded.Add($piece)
                }
            }
            continue
        }

        $expanded.Add($trimmed)
    }

    return $expanded
}

function Add-ExtraDartDefinesToFlutterArgs {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[string]]$FlutterArgs,
        [string[]]$ExtraDefines
    )

    $normalizedDefines = Expand-DartDefineInputs -Inputs $ExtraDefines
    if ($normalizedDefines.Count -eq 0) {
        return
    }

    $existingKeys = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase)

    foreach ($arg in $FlutterArgs) {
        if ($arg -match '^--dart-define=') {
            $key = Get-DartDefineKeyFromEntry -Entry $arg
            if ($key) {
                [void]$existingKeys.Add($key)
            }
        }
    }

    foreach ($entry in $normalizedDefines) {
        $defineArg = ConvertTo-DartDefineArg -Entry $entry
        if (-not $defineArg) {
            continue
        }

        $key = Get-DartDefineKeyFromEntry -Entry $defineArg
        if ($key -and $existingKeys.Contains($key)) {
            Write-TerminalLog "Skipping duplicate dart-define: $key" -ForegroundColor DarkGray
            continue
        }

        $FlutterArgs.Add($defineArg)
        if ($key) {
            [void]$existingKeys.Add($key)
        }
    }
}

function Get-ExternalCommand {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return $null
    }

    try {
        $value = (Get-Content -Path $Path -Raw -ErrorAction Stop).Trim().ToLowerInvariant()
        Clear-Content -Path $Path -ErrorAction SilentlyContinue
        if ([string]::IsNullOrWhiteSpace($value)) {
            return $null
        }
        return $value
    }
    catch {
        return $null
    }
}

function Start-ControllerWindow {
    param(
        [string]$ControllerScript,
        [string]$CommandFilePath,
        [string]$LockFilePath,
        [string]$AppName,
        [bool]$ReleaseMode = $false
    )

    if (-not (Test-Path $ControllerScript)) {
        throw "recording_controller.ps1 not found: $ControllerScript"
    }

    $pwshPath = Get-PwshCommandPath

    $controllerArgs = @(
        "-ExecutionPolicy", "Bypass",
        "-File", $ControllerScript,
        "-CommandFilePath", $CommandFilePath,
        "-LockFilePath", $LockFilePath,
        "-AppName", $AppName
    )
    if ($ReleaseMode) {
        $controllerArgs += "-ReleaseMode"
    }

    return Start-Process `
        -FilePath $pwshPath `
        -ArgumentList $controllerArgs `
        -WorkingDirectory $CurrentDir `
        -PassThru
}

Ensure-Directory -Path $LocalSaveDir

if (Test-Path $CommandFile) {
    Remove-Item $CommandFile -Force -ErrorAction SilentlyContinue
}
Set-Content -Path $LockFile -Value ("started " + (Get-Date).ToString("s")) -Encoding UTF8

if (-not (Test-CommandExists "flutter")) {
    throw "flutter command not found. Check PATH."
}
if (-not (Test-CommandExists "adb")) {
    throw "adb command not found. Check PATH."
}

$selectedBuildMode = Select-BuildMode
$script:IsReleaseMode = ($selectedBuildMode -eq "release")

Write-Section "Check adb devices"
$selectedDevice = Select-AndroidDevice
$deviceId = $selectedDevice.Id

Write-TerminalLog "Device       : $deviceId [$($selectedDevice.Manufacturer) $($selectedDevice.Model)]" -ForegroundColor Green
Write-TerminalLog "Build mode   : $selectedBuildMode$(if ($script:IsReleaseMode) { ' (no DEBUG banner)' } else { ' (hot reload)' })" -ForegroundColor Green
Write-TerminalLog "Project dir  : $CurrentDir" -ForegroundColor Green
Write-TerminalLog "App name     : $SafeAppName" -ForegroundColor Green

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$ScreenshotDir = Join-Path $LocalSaveDir ("screenshots_" + $timestamp)
Ensure-Directory -Path $ScreenshotDir

# 統合ログ（ChatGPT 提出用）。スクショフォルダ直下。iOS では adb/screenrecord が無いため別フローが必要（移植監査メモは終了時報告にも記載）。
$script:TerminalOutputLogPath = Join-Path $ScreenshotDir ("terminal_output_" + $timestamp + ".txt")
try {
    $demoNote = if ($DemoMode) { "yes" } else { "no" }
    $sessionHeader = @(
        "=== room_manager2 session log (ChatGPT bundle; UTF-8, no BOM) ===",
        "Started (local): $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "Project directory: $CurrentDir",
        "App name (safe folder token): $SafeAppName",
        "Build mode: $selectedBuildMode",
        "DemoMode: $demoNote",
        "RakutenAppId: $(if ($RakutenAppId) { '(set)' } else { '(empty)' })",
        "RakutenAffiliateId: $(if ($RakutenAffiliateId) { '(set)' } else { '(empty)' })",
        "Extra dart-defines: $(if ($DartDefine -and $DartDefine.Count -gt 0) { (($DartDefine | ForEach-Object { ConvertTo-RedactedDartDefineEntry -Entry $_ }) -join '; ') } else { '(none)' })",
        "Selected device ID: $deviceId",
        "Device manufacturer: $($selectedDevice.Manufacturer)",
        "Device model: $($selectedDevice.Model)",
        "",
        "--- Session events ---",
        ""
    ) -join [Environment]::NewLine
    [System.IO.File]::WriteAllText($script:TerminalOutputLogPath, $sessionHeader, [System.Text.UTF8Encoding]::new($false))
}
catch {
}

Write-TerminalLogSection "Check adb devices"

$localFileName = "{0}_{1}.mp4" -f $SafeAppName, $timestamp
$flutterStdOutLogName = "{0}_flutter_stdout_{1}.log" -f $SafeAppName, $timestamp
$flutterStdErrLogName = "{0}_flutter_stderr_{1}.log" -f $SafeAppName, $timestamp
$recorderStdOutLogName = "{0}_screenrecord_stdout_{1}.log" -f $SafeAppName, $timestamp
$recorderStdErrLogName = "{0}_screenrecord_stderr_{1}.log" -f $SafeAppName, $timestamp

$localVideoPath = Join-Path $LocalSaveDir $localFileName
$flutterStdOutLogFile = Join-Path $LocalSaveDir $flutterStdOutLogName
$flutterStdErrLogFile = Join-Path $LocalSaveDir $flutterStdErrLogName
$recorderStdOutLogFile = Join-Path $LocalSaveDir $recorderStdOutLogName
$recorderStdErrLogFile = Join-Path $LocalSaveDir $recorderStdErrLogName

Write-Section "Remove old remote video"
Write-TerminalLogSection "Remove old remote video"
try {
    adb -s $deviceId shell "rm -f '$RemoteVideoPath'" | Out-Host
}
catch {
}

Write-Section "Start screen recording"
Write-TerminalLogSection "Start screen recording"
Write-TerminalLog "Device ID              : $deviceId" -ForegroundColor Yellow
Write-TerminalLog "Remote video path      : $RemoteVideoPath" -ForegroundColor Yellow
Write-TerminalLog "Local video path       : $localVideoPath" -ForegroundColor Yellow
Write-TerminalLog "Flutter stdout log     : $flutterStdOutLogFile" -ForegroundColor Yellow
Write-TerminalLog "Flutter stderr log     : $flutterStdErrLogFile" -ForegroundColor Yellow
Write-TerminalLog "Recorder stdout log    : $recorderStdOutLogFile" -ForegroundColor Yellow
Write-TerminalLog "Recorder stderr log    : $recorderStdErrLogFile" -ForegroundColor Yellow
Write-TerminalLog "Screenshot dir         : $ScreenshotDir" -ForegroundColor Yellow
Write-TerminalLog "Terminal output log    : $script:TerminalOutputLogPath" -ForegroundColor Yellow
Write-TerminalLog "Command file           : $CommandFile" -ForegroundColor Yellow
Write-TerminalLog ""

Show-Help -ReleaseMode:$script:IsReleaseMode

$screenArgs = @("-s", $deviceId, "shell", "screenrecord", "--bit-rate", "$VideoBitRate", $RemoteVideoPath)
$null = Start-Process `
    -FilePath "adb" `
    -ArgumentList $screenArgs `
    -RedirectStandardOutput $recorderStdOutLogFile `
    -RedirectStandardError $recorderStdErrLogFile `
    -PassThru `
    -WindowStyle Hidden

Start-Sleep -Seconds 2

Write-TerminalLog "[SCREENRECORD] adb screenrecord started (remote: $RemoteVideoPath, bitrate: $VideoBitRate). Details: recorder logs under recordings\."

Write-Section "Start controller window"
Write-TerminalLogSection "Start controller window"
$controllerProcess = Start-ControllerWindow `
    -ControllerScript $ControllerScriptPath `
    -CommandFilePath $CommandFile `
    -LockFilePath $LockFile `
    -AppName $SafeAppName `
    -ReleaseMode:$script:IsReleaseMode

Write-TerminalLog "[CONTROLLER] Secondary controller window started (PID: $($controllerProcess.Id))."

Write-Section "Start flutter"
Write-TerminalLogSection "Start flutter"

$flutterArgs = [System.Collections.Generic.List[string]]::new()
$flutterArgs.AddRange([string[]]@(
    "run",
    "-d", $deviceId,
    "--dart-define=RAKUTEN_APP_ID=$RakutenAppId",
    "--dart-define=RAKUTEN_AFFILIATE_ID=$RakutenAffiliateId"
))

if ($DemoMode) {
    $flutterArgs.Add("--dart-define=DEMO_MODE=true")
}

if ($script:IsReleaseMode) {
    $flutterArgs.Add("--release")
}

Add-ExtraDartDefinesToFlutterArgs -FlutterArgs $flutterArgs -ExtraDefines $DartDefine

$flutterExe = Get-FlutterCommandPath
$flutterStartFile = $flutterExe
$flutterStartArgs = [string[]]$flutterArgs
$flutterExeLower = $flutterExe.ToLowerInvariant()
if ($flutterExeLower.EndsWith(".cmd") -or $flutterExeLower.EndsWith(".bat")) {
    $flutterStartFile = "cmd.exe"
    $flutterStartArgs = @("/c", $flutterExe) + [string[]]$flutterArgs
}

$flutterStartInfo = New-Object System.Diagnostics.ProcessStartInfo
$flutterStartInfo.FileName = $flutterStartFile
$flutterStartInfo.WorkingDirectory = $CurrentDir
$flutterStartInfo.UseShellExecute = $false
$flutterStartInfo.RedirectStandardInput = $true
$flutterStartInfo.RedirectStandardOutput = $true
$flutterStartInfo.RedirectStandardError = $true
$flutterStartInfo.CreateNoWindow = $true

foreach ($arg in $flutterStartArgs) {
    $null = $flutterStartInfo.ArgumentList.Add($arg)
}

$flutterProc = New-Object System.Diagnostics.Process
$flutterProc.StartInfo = $flutterStartInfo
$null = $flutterProc.Start()

Write-TerminalLog "[FLUTTER] Launch command: $(Get-RedactedFlutterLaunchCommand -StartFile $flutterStartFile -StartArgs $flutterStartArgs)"

$stdoutWriter = [System.IO.StreamWriter]::new($flutterStdOutLogFile, $false, [System.Text.UTF8Encoding]::new($false))
$stderrWriter = [System.IO.StreamWriter]::new($flutterStdErrLogFile, $false, [System.Text.UTF8Encoding]::new($false))
$ioSync = [hashtable]::Synchronized(@{
    StdOut          = $stdoutWriter
    StdErr          = $stderrWriter
    TerminalLogPath = $script:TerminalOutputLogPath
})

$stdoutEvent = Register-ObjectEvent -InputObject $flutterProc -EventName OutputDataReceived -MessageData $ioSync -Action {
    if ($null -ne $EventArgs.Data) {
        $state = $event.MessageData
        [System.Threading.Monitor]::Enter($state)
        try {
            $state.StdOut.WriteLine($EventArgs.Data)
            $state.StdOut.Flush()
        }
        finally {
            [System.Threading.Monitor]::Exit($state)
        }
        Write-Host $EventArgs.Data
        $tp = $state.TerminalLogPath
        if (-not [string]::IsNullOrWhiteSpace($tp)) {
            try {
                [System.IO.File]::AppendAllText($tp, $EventArgs.Data + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
            }
            catch {
            }
        }
    }
}

$stderrEvent = Register-ObjectEvent -InputObject $flutterProc -EventName ErrorDataReceived -MessageData $ioSync -Action {
    if ($null -ne $EventArgs.Data) {
        $state = $event.MessageData
        [System.Threading.Monitor]::Enter($state)
        try {
            $state.StdErr.WriteLine($EventArgs.Data)
            $state.StdErr.Flush()
        }
        finally {
            [System.Threading.Monitor]::Exit($state)
        }
        Write-Host $EventArgs.Data -ForegroundColor DarkYellow
        $tp = $state.TerminalLogPath
        if (-not [string]::IsNullOrWhiteSpace($tp)) {
            try {
                [System.IO.File]::AppendAllText($tp, $EventArgs.Data + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
            }
            catch {
            }
        }
    }
}

$flutterProc.BeginOutputReadLine()
$flutterProc.BeginErrorReadLine()

Write-TerminalLog ""
$flutterModeNote = if ($script:IsReleaseMode) {
    "Flutter started (release). Use the separate controller window."
} else {
    "Flutter started (debug). Use the separate controller window."
}
Write-TerminalLog $flutterModeNote -ForegroundColor Green
Write-TerminalLog "Streaming flutter logs below..." -ForegroundColor Green
Write-TerminalLog ""

$stopRequestedByQ = $false

try {
    while (-not $flutterProc.HasExited) {
        Start-Sleep -Milliseconds 300

        $command = Get-ExternalCommand -Path $CommandFile

        if ($null -eq $command) {
            continue
        }

        switch ($command) {
            "q" {
                $stopRequestedByQ = $true
                Write-TerminalLog ""
                Write-TerminalLog "[QUIT] Q received; stopping Flutter and controller." -ForegroundColor Yellow
                Write-TerminalLog "Stop command received. Stopping flutter..." -ForegroundColor Yellow
                try {
                    if (-not $flutterProc.HasExited) {
                        Start-Sleep -Seconds 1
                        $flutterProc.Kill()
                        if (-not $flutterProc.WaitForExit(5000)) {
                            Write-TerminalLog "Flutter process did not exit in time. Continue cleanup." -ForegroundColor Yellow
                        }
                    }
                } catch {}
                try {
                    if ($controllerProcess -and -not $controllerProcess.HasExited) {
                        $controllerProcess.Kill()
                        if (-not $controllerProcess.WaitForExit(3000)) {
                            Write-TerminalLog "Controller window did not close in time." -ForegroundColor Yellow
                        }
                    }
                } catch {}
                break
            }

            "s" {
                try {
                    $shotPath = Get-NextScreenshotPath -ScreenshotDirPath $ScreenshotDir -AppName $SafeAppName
                    Save-Screenshot -DeviceId $deviceId -ScreenshotPath $shotPath
                    Write-TerminalLog "[SCREENSHOT] saved: $shotPath"
                } catch {
                    Write-Host "Screenshot failed: $($_.Exception.Message)" -ForegroundColor Red
                    Write-TerminalLog "[SCREENSHOT] Failed: $($_.Exception.Message)" -ForegroundColor Red
                }
            }

            "r" {
                if ($script:IsReleaseMode) {
                    Write-TerminalLog "[HOT RELOAD] Skipped: not available in release mode." -ForegroundColor Yellow
                }
                else {
                    try {
                        if (-not $flutterProc.HasExited) {
                            $flutterProc.StandardInput.WriteLine("r")
                            $flutterProc.StandardInput.Flush()
                            Write-TerminalLog "[HOT RELOAD] Sent 'r' to Flutter stdin. Hot reload command sent." -ForegroundColor Green
                        }
                    } catch {
                        Write-Host "Hot reload failed: $($_.Exception.Message)" -ForegroundColor Red
                        Write-TerminalLog "[HOT RELOAD] Failed: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
            }

            "h" {
                Show-Help -ReleaseMode:$script:IsReleaseMode
            }
        }
    }

    Write-Section "Flutter process ended"
    Write-TerminalLogSection "Flutter process ended"
    Write-TerminalLog "[FLUTTER] Process ended. stopRequestedByQ=$stopRequestedByQ"
}
finally {
    Write-TerminalLogSection "Flutter cleanup (streams/controller)"
    Write-TerminalLog "[SESSION] Closing Flutter output streams and stopping controller if still running."
    try { $flutterProc.CancelOutputRead() } catch {}
    try { $flutterProc.CancelErrorRead() } catch {}
    try { Unregister-Event -SourceIdentifier $stdoutEvent.Name -ErrorAction SilentlyContinue } catch {}
    try { Unregister-Event -SourceIdentifier $stderrEvent.Name -ErrorAction SilentlyContinue } catch {}
    try { Remove-Job -Id $stdoutEvent.Id -Force -ErrorAction SilentlyContinue } catch {}
    try { Remove-Job -Id $stderrEvent.Id -Force -ErrorAction SilentlyContinue } catch {}
    try { $stdoutWriter.Dispose() } catch {}
    try { $stderrWriter.Dispose() } catch {}
    try {
        if ($controllerProcess -and -not $controllerProcess.HasExited) {
            $controllerProcess.Kill()
            $controllerProcess.WaitForExit()
        }
    } catch {}

    if (Test-Path $LockFile) {
        Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
    }
}

Stop-AndroidScreenRecord -DeviceId $deviceId

function Open-OutputFolder {
    param([string]$Path)
    try {
        explorer $Path
    }
    catch {
        Write-TerminalLog "Could not open folder: $Path" -ForegroundColor Yellow
    }
}

Write-Section "Pull recorded video"
Write-TerminalLogSection "Pull recorded video"

if (Test-RemoteFileExists -DeviceId $deviceId -RemotePath $RemoteVideoPath) {
    Write-TerminalLog "[VIDEO] adb pull (remote -> local): $RemoteVideoPath -> $localVideoPath"
    adb -s $deviceId pull $RemoteVideoPath $localVideoPath | Out-Host

    if (Test-Path -LiteralPath $localVideoPath) {
        try {
            $videoLen = (Get-Item -LiteralPath $localVideoPath).Length
            Write-TerminalLog "[VIDEO] Pulled OK. Local file: $localVideoPath ($videoLen bytes)"
        }
        catch {
            Write-TerminalLog "[VIDEO] Pulled OK. Local file: $localVideoPath"
        }
    }
    else {
        Write-TerminalLog "[VIDEO] WARNING: Local file not found after adb pull."
    }

    Write-Section "Delete remote video"
    Write-TerminalLogSection "Delete remote video"
    try {
        adb -s $deviceId shell "rm -f '$RemoteVideoPath'" | Out-Host
    }
    catch {
    }

    Write-Section "Open screenshot folder"
    Write-TerminalLogSection "Open screenshot folder"
    Open-OutputFolder -Path $ScreenshotDir

    Write-TerminalLog ""
    Write-TerminalLog "--- Final artifact paths (ChatGPT bundle) ---" -ForegroundColor Green
    Write-TerminalLog "Screenshot folder        : $ScreenshotDir"
    Write-TerminalLog "Unified terminal log     : $script:TerminalOutputLogPath"
    Write-TerminalLog "Video (recordings\)      : $localVideoPath"
    Write-TerminalLog "Flutter stdout log       : $flutterStdOutLogFile"
    Write-TerminalLog "Flutter stderr log       : $flutterStdErrLogFile"
    Write-TerminalLog "Recorder stdout log      : $recorderStdOutLogFile"
    Write-TerminalLog "Recorder stderr log      : $recorderStdErrLogFile"
    Write-TerminalLog ""
    Write-TerminalLog "Done." -ForegroundColor Green
    if ($stopRequestedByQ) {
        Write-TerminalLog "Stopped by Q command." -ForegroundColor Green
    }
    Write-TerminalLog ""
    Write-TerminalLog "ChatGPT: Open the screenshot folder in Explorer, select all PNG screenshots and terminal_output_*.txt together, then attach." -ForegroundColor Green
}
else {
    Write-TerminalLog "[VIDEO] Remote recorded video was not found at $RemoteVideoPath (pull skipped)." -ForegroundColor Red
    if ($stopRequestedByQ) {
        Write-TerminalLog "Stopped by Q command." -ForegroundColor Yellow
    }
    Write-Section "Open screenshot folder"
    Write-TerminalLogSection "Open screenshot folder"
    Open-OutputFolder -Path $ScreenshotDir

    Write-TerminalLog ""
    Write-TerminalLog "--- Final artifact paths (ChatGPT bundle) ---" -ForegroundColor Green
    Write-TerminalLog "Screenshot folder        : $ScreenshotDir"
    Write-TerminalLog "Unified terminal log     : $script:TerminalOutputLogPath"
    Write-TerminalLog "Video                    : (not pulled - remote file missing)"
    Write-TerminalLog "Flutter stdout log       : $flutterStdOutLogFile"
    Write-TerminalLog "Flutter stderr log       : $flutterStdErrLogFile"
    Write-TerminalLog "Recorder stdout log      : $recorderStdOutLogFile"
    Write-TerminalLog "Recorder stderr log      : $recorderStdErrLogFile"
    Write-TerminalLog ""
    Write-TerminalLog "Done (video not found on device)." -ForegroundColor Yellow
    Write-TerminalLog ""
    Write-TerminalLog "ChatGPT: Open the screenshot folder in Explorer, select all PNG screenshots and terminal_output_*.txt together, then attach." -ForegroundColor Green
}