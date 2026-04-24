# start_avd.ps1
# Android Studioで作成済みのAVDを選択して起動するスクリプト

$ErrorActionPreference = "Stop"

$emulatorPath = "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe"

if (!(Test-Path $emulatorPath)) {
    Write-Host "emulator.exe が見つかりません。" -ForegroundColor Red
    Write-Host "確認パス: $emulatorPath"
    exit 1
}

$avds = & $emulatorPath -list-avds

if (!$avds -or $avds.Count -eq 0) {
    Write-Host "AVDが見つかりません。" -ForegroundColor Red
    Write-Host "Android Studioで仮想端末を作成してください。"
    exit 1
}

Write-Host ""
Write-Host "起動する仮想端末を選択してください。" -ForegroundColor Cyan
Write-Host ""

for ($i = 0; $i -lt $avds.Count; $i++) {
    Write-Host "$($i + 1): $($avds[$i])"
}

Write-Host ""
$selected = Read-Host "番号を入力"

if ($selected -notmatch '^\d+$') {
    Write-Host "番号を入力してください。" -ForegroundColor Red
    exit 1
}

$index = [int]$selected - 1

if ($index -lt 0 -or $index -ge $avds.Count) {
    Write-Host "範囲外の番号です。" -ForegroundColor Red
    exit 1
}

$avdName = $avds[$index]

Write-Host ""
Write-Host "AVDを起動します: $avdName" -ForegroundColor Green

Start-Process -FilePath $emulatorPath -ArgumentList "-avd `"$avdName`""

Write-Host ""
Write-Host "起動後、確認する場合は以下を実行してください。"
Write-Host "flutter devices" -ForegroundColor Yellow