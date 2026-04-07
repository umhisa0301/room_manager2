$commandFile = Join-Path (Join-Path (Get-Location).Path "recordings") "recording_command.txt"
Set-Content -Path $commandFile -Value "q" -Encoding UTF8
Write-Host "Stop command sent."