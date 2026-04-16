param(
    [Parameter(Mandatory = $true)]
    [string]$CommandFilePath,

    [Parameter(Mandatory = $true)]
    [string]$LockFilePath,

    [string]$AppName = "app"
)

$ErrorActionPreference = "Continue"

function Write-Command {
    param([string]$Value)

    try {
        Set-Content -Path $CommandFilePath -Value $Value -Encoding UTF8
    }
    catch {
        Write-Host ("Write failed: " + $_.Exception.Message) -ForegroundColor Red
    }
}

function Show-Help {
    Write-Host ""
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host ("Controller - " + $AppName) -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "S : Screenshot" -ForegroundColor Green
    Write-Host "Q : Stop and Save" -ForegroundColor Yellow
    Write-Host "H : Help" -ForegroundColor Cyan
    Write-Host ""
}

Show-Help

while ($true) {
    if (-not (Test-Path $LockFilePath)) {
        Write-Host ""
        Write-Host "Session ended. Closing..." -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        exit
    }

    try {
        $key = [Console]::ReadKey($true)

        switch ($key.Key.ToString().ToUpperInvariant()) {
            "S" {
                Write-Command "s"
                Write-Host ("[" + (Get-Date -Format "HH:mm:ss") + "] Screenshot") -ForegroundColor Green
            }

            "Q" {
                Write-Command "q"
                Write-Host ("[" + (Get-Date -Format "HH:mm:ss") + "] Stop") -ForegroundColor Yellow
            }

            "H" {
                Show-Help
            }

            default {
            }
        }
    }
    catch {
        Write-Host ("Error: " + $_.Exception.Message) -ForegroundColor Red
        Start-Sleep -Seconds 1
    }
}