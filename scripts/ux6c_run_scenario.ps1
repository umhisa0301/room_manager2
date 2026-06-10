param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('recentSync', 'noHistory', 'eligible', 'noticeIncreased', 'manualConflict')]
    [string]$Scenario,
    [Parameter(Mandatory = $true)]
    [string]$OutDir
)

$ErrorActionPreference = 'Stop'
$Device = 'SXILHMB270711564'
$Package = 'com.stepbytestudio.room_manager2'
$Repo = 'C:\dev\app_project\room_manager2'

function Invoke-Adb([string[]]$AdbArgs) {
    & adb -s $Device @AdbArgs
    if ($LASTEXITCODE -ne 0) { throw "adb failed: $($AdbArgs -join ' ')" }
}

function Wait-AutoSyncLog([int]$Seconds = 12) {
    $proc = Start-Process -FilePath 'adb' -ArgumentList @('-s', $Device, 'logcat', '-v', 'time', 'flutter:I', '*:S') -RedirectStandardOutput ([System.IO.Path]::Combine($OutDir, "${Scenario}_live.logcat")) -PassThru -NoNewWindow
    Start-Sleep -Seconds $Seconds
    if (-not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    }
}

if ($Scenario -ne 'manualConflict') {
    py (Join-Path $Repo 'scripts\ux6c_patch_history.py') $Scenario
}

Invoke-Adb @('shell', 'am', 'force-stop', $Package)
Start-Sleep -Milliseconds 800
Invoke-Adb @('logcat', '-c')

if ($Scenario -eq 'manualConflict') {
    py (Join-Path $Repo 'scripts\ux6c_patch_history.py') 'eligible'
    Invoke-Adb @('shell', 'monkey', '-p', $Package, '-c', 'android.intent.category.LAUNCHER', '1')
    Start-Sleep -Seconds 4
    # 自動反応確認開始直前〜実行中に手動ボタン領域をタップ（ホーム下部付近）
    Invoke-Adb @('shell', 'uiautomator', 'dump', '/sdcard/ux6c_window.xml')
    Invoke-Adb @('pull', '/sdcard/ux6c_window.xml', (Join-Path $OutDir 'manualConflict_ui.xml'))
    # 反応確認ボタン付近を複数タップ（スクロール位置により変動するため）
    Invoke-Adb @('shell', 'input', 'tap', '540', '1750')
    Start-Sleep -Milliseconds 400
    Invoke-Adb @('shell', 'input', 'tap', '540', '1850')
    Wait-AutoSyncLog -Seconds 10
}
else {
    Invoke-Adb @('shell', 'monkey', '-p', $Package, '-c', 'android.intent.category.LAUNCHER', '1')
    Wait-AutoSyncLog -Seconds 12
}

$dumpPath = Join-Path $OutDir "${Scenario}.logcat.txt"
& adb -s $Device logcat -d | Select-String -Pattern 'flutter|AUTO_REACTION_SYNC|ROOM_REACTION_SYNC_START_GUARD|FlutterError|EXCEPTION CAUGHT' | ForEach-Object { $_.Line } | Out-File -FilePath $dumpPath -Encoding utf8

$auto = Select-String -Path $dumpPath -Pattern '\[AUTO_REACTION_SYNC\]' | ForEach-Object { $_.Line.Trim() }
$guard = Select-String -Path $dumpPath -Pattern '\[ROOM_REACTION_SYNC_START_GUARD\]' | ForEach-Object { $_.Line.Trim() }
$errors = Select-String -Path $dumpPath -Pattern 'FlutterError|EXCEPTION CAUGHT|Another exception' | ForEach-Object { $_.Line.Trim() }

Write-Host "=== $Scenario ==="
$auto | ForEach-Object { Write-Host $_ }
if ($guard) {
    Write-Host '--- guard ---'
    $guard | ForEach-Object { Write-Host $_ }
}
if ($errors) {
    Write-Host '--- errors ---'
    $errors | ForEach-Object { Write-Host $_ }
}
