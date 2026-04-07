$commandFile = Join-Path (Join-Path (Get-Location).Path "recordings") "recording_command.txt"
Set-Content -Path $commandFile -Value "s" -Encoding UTF8
Write-Host "Screenshot command sent."