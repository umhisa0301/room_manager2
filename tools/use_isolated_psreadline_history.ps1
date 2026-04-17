# Cursor / Windows Terminal など複数の PowerShell が同時に動くと、
# PSReadLine の既定履歴ファイルがロックされ
# 「ConsoleHost_history.txt ... being used by another process」が出ることがある。
#
# 対策: このファイルをプロファイルの先頭でドットソースする。
#   . "C:\dev\app_project\room_manager2\tools\use_isolated_psreadline_history.ps1"
#
# 各プロセス PID ごとに履歴ファイルを分ける（既定の共有ファイルと競合しない）。

try {
    if (Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue) {
        $histDir = Join-Path $env:LOCALAPPDATA "room_manager2_psreadline"
        if (-not (Test-Path $histDir)) {
            New-Item -ItemType Directory -Path $histDir -Force | Out-Null
        }
        Set-PSReadLineOption -HistorySavePath (Join-Path $histDir "history_terminal_$PID.txt") -ErrorAction SilentlyContinue
    }
} catch {}
