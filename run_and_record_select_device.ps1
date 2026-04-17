param(
    [string]$RakutenAppId = "1067117285680395162",
    [string]$RakutenAffiliateId = "3d96198d.dce5f4ee.3d96198e.ed8cdd87",
    [string]$RemoteVideoPath = "/sdcard/Movies/play_demo.mp4",
    [int]$VideoBitRate = 8000000,
    [switch]$DemoMode
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
$ScreenshotDir = Join-Path $LocalSaveDir "screenshots"
$CommandFile = Join-Path $LocalSaveDir "recording_command.txt"
$LockFile = Join-Path $LocalSaveDir "recording_session.lock"
$ControllerScriptPath = Join-Path $CurrentDir "recording_controller.ps1"

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
    Write-Host ""
    Write-Host "Controller window commands:" -ForegroundColor Cyan
    Write-Host "  S : save screenshot" -ForegroundColor Cyan
    Write-Host "  Q : stop flutter and collect video" -ForegroundColor Cyan
    Write-Host "  H : show help" -ForegroundColor Cyan
    Write-Host ""
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
        [string]$AppName
    )

    if (-not (Test-Path $ControllerScript)) {
        throw "recording_controller.ps1 not found: $ControllerScript"
    }

    $pwshPath = Get-PwshCommandPath

    $controllerArgs = @(
        "-NoExit",
        "-ExecutionPolicy", "Bypass",
        "-File", $ControllerScript,
        "-CommandFilePath", $CommandFilePath,
        "-LockFilePath", $LockFilePath,
        "-AppName", $AppName
    )

    Start-Process `
        -FilePath $pwshPath `
        -ArgumentList $controllerArgs `
        -WorkingDirectory $CurrentDir | Out-Null
}

Ensure-Directory -Path $LocalSaveDir
Ensure-Directory -Path $ScreenshotDir

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

Write-Section "Check adb devices"
$selectedDevice = Select-AndroidDevice
$deviceId = $selectedDevice.Id

Write-Host "Device       : $deviceId [$($selectedDevice.Manufacturer) $($selectedDevice.Model)]" -ForegroundColor Green
Write-Host "Project dir  : $CurrentDir" -ForegroundColor Green
Write-Host "App name     : $SafeAppName" -ForegroundColor Green

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

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
try {
    adb -s $deviceId shell "rm -f '$RemoteVideoPath'" | Out-Host
} catch {}

Write-Section "Start screen recording"
Write-Host "Device ID              : $deviceId" -ForegroundColor Yellow
Write-Host "Remote video path      : $RemoteVideoPath" -ForegroundColor Yellow
Write-Host "Local video path       : $localVideoPath" -ForegroundColor Yellow
Write-Host "Flutter stdout log     : $flutterStdOutLogFile" -ForegroundColor Yellow
Write-Host "Flutter stderr log     : $flutterStdErrLogFile" -ForegroundColor Yellow
Write-Host "Recorder stdout log    : $recorderStdOutLogFile" -ForegroundColor Yellow
Write-Host "Recorder stderr log    : $recorderStdErrLogFile" -ForegroundColor Yellow
Write-Host "Screenshot dir         : $ScreenshotDir" -ForegroundColor Yellow
Write-Host "Command file           : $CommandFile" -ForegroundColor Yellow
Write-Host ""

Show-Help

$screenArgs = @("-s", $deviceId, "shell", "screenrecord", "--bit-rate", "$VideoBitRate", $RemoteVideoPath)
$null = Start-Process `
    -FilePath "adb" `
    -ArgumentList $screenArgs `
    -RedirectStandardOutput $recorderStdOutLogFile `
    -RedirectStandardError $recorderStdErrLogFile `
    -PassThru `
    -WindowStyle Hidden

Start-Sleep -Seconds 2

Write-Section "Start controller window"
Start-ControllerWindow `
    -ControllerScript $ControllerScriptPath `
    -CommandFilePath $CommandFile `
    -LockFilePath $LockFile `
    -AppName $SafeAppName

Write-Section "Start flutter"

$flutterArgs = @(
    "run",
    "-d", $deviceId,
    "--dart-define=RAKUTEN_APP_ID=$RakutenAppId",
    "--dart-define=RAKUTEN_AFFILIATE_ID=$RakutenAffiliateId"
)

if ($DemoMode) {
    $flutterArgs += "--dart-define=DEMO_MODE=true"
}

$flutterExe = Get-FlutterCommandPath

$flutterProc = Start-Process `
    -FilePath $flutterExe `
    -ArgumentList $flutterArgs `
    -WorkingDirectory $CurrentDir `
    -RedirectStandardOutput $flutterStdOutLogFile `
    -RedirectStandardError $flutterStdErrLogFile `
    -PassThru

Write-Host ""
Write-Host "Flutter started. Use the separate controller window." -ForegroundColor Green
Write-Host "Showing flutter stdout below..." -ForegroundColor Green
Write-Host ""

$tailJob = Start-Job -ScriptBlock {
    param($Path)

    if (-not (Test-Path $Path)) {
        New-Item -ItemType File -Path $Path -Force | Out-Null
    }

    Get-Content -Path $Path -Wait
} -ArgumentList $flutterStdOutLogFile

try {
    while (-not $flutterProc.HasExited) {
        Start-Sleep -Milliseconds 300

        $tailOutput = Receive-Job -Job $tailJob -ErrorAction SilentlyContinue
        if ($tailOutput) {
            foreach ($line in $tailOutput) {
                Write-Host $line
            }
        }

        $command = Get-ExternalCommand -Path $CommandFile

        switch ($command) {
            "q" {
                Write-Host ""
                Write-Host "Stop command received. Stopping flutter..." -ForegroundColor Yellow
                try {
                    if (-not $flutterProc.HasExited) {
                        Start-Sleep -Seconds 1
                        $flutterProc.Kill()
                        $flutterProc.WaitForExit()
                    }
                } catch {}
                break
            }

            "s" {
                try {
                    $shotPath = Get-NextScreenshotPath -ScreenshotDirPath $ScreenshotDir -AppName $SafeAppName
                    Save-Screenshot -DeviceId $deviceId -ScreenshotPath $shotPath
                } catch {
                    Write-Host "Screenshot failed: $($_.Exception.Message)" -ForegroundColor Red
                }
            }

            "h" {
                Show-Help
            }
        }
    }

    Start-Sleep -Seconds 1

    $tailOutput = Receive-Job -Job $tailJob -ErrorAction SilentlyContinue
    if ($tailOutput) {
        foreach ($line in $tailOutput) {
            Write-Host $line
        }
    }

    Write-Section "Flutter process ended"
}
finally {
    if ($tailJob) {
        try { Stop-Job $tailJob -ErrorAction SilentlyContinue } catch {}
        try { Remove-Job $tailJob -Force -ErrorAction SilentlyContinue } catch {}
    }

    if (Test-Path $LockFile) {
        Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
    }
}

Stop-AndroidScreenRecord -DeviceId $deviceId

Write-Section "Pull recorded video"

if (Test-RemoteFileExists -DeviceId $deviceId -RemotePath $RemoteVideoPath) {
    adb -s $deviceId pull $RemoteVideoPath $localVideoPath | Out-Host

    Write-Section "Delete remote video"
    adb -s $deviceId shell "rm -f '$RemoteVideoPath'" | Out-Host

    Write-Section "Open output folder"
    explorer $LocalSaveDir

    Write-Host ""
    Write-Host "Done." -ForegroundColor Green
    Write-Host "Video               : $localVideoPath" -ForegroundColor Green
    Write-Host "Flutter stdout log  : $flutterStdOutLogFile" -ForegroundColor Green
    Write-Host "Flutter stderr log  : $flutterStdErrLogFile" -ForegroundColor Green
    Write-Host "Recorder stdout log : $recorderStdOutLogFile" -ForegroundColor Green
    Write-Host "Recorder stderr log : $recorderStdErrLogFile" -ForegroundColor Green
    Write-Host "Screenshot dir      : $ScreenshotDir" -ForegroundColor Green
}
else {
    Write-Host "Remote recorded video was not found." -ForegroundColor Red
    explorer $LocalSaveDir
}