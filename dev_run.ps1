# =========================================
# Flutter Dev Run Script
# 安全実行用（実行フォルダ事故防止）
# =========================================

# このスクリプトが置いてあるフォルダへ移動
Set-Location $PSScriptRoot

Write-Host ""
Write-Host "==============================="
Write-Host " PROJECT: $PSScriptRoot"
Write-Host "==============================="
Write-Host ""

# Git状態確認
if (Test-Path ".git") {
    Write-Host "---- GIT STATUS ----"
    git status
    Write-Host ""
}

# 依存関係取得
Write-Host "---- FLUTTER PUB GET ----"
flutter pub get
Write-Host ""

# 接続デバイス確認
Write-Host "---- DEVICES ----"
flutter devices
Write-Host ""

# 実行
Write-Host "---- RUN START ----"
flutter run