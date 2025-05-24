<#
    .EXAMPLE
        Set-EntraIDELMSettings.ps1 -JsonPath "C:\path\to\settings.json" -EnableLogs
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$JsonPath,

    [Parameter(Mandatory = $false)]
    [switch]$EnableLogs
)

try {
    if ($EnableLogs) {
        $scriptPath = $MyInvocation.MyCommand.Path
        $scriptDir = Join-Path -Path (Split-Path -Path $scriptPath) -ChildPath "Logs"
        if (-not (Test-Path $scriptDir)) {
            New-Item -ItemType Directory -Path $scriptDir | Out-Null
        }
        $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($scriptPath)
        $dateTime = (Get-Date).ToString("yyyy_MM-dd HH_mm_ss")
        $logFileName = "$scriptName`_$dateTime.log"
        $logFilePath = Join-Path -Path $scriptDir -ChildPath $logFileName
        Start-Transcript -Path $logFilePath -NoClobber -UseMinimalHeader -Append -Force
    }

    $message = $MyInvocation.MyCommand.Name
    Write-Host "[$message]: " -NoNewline
    Write-Host "🚀 Starting Entitlement Management settings setup." -ForegroundColor Cyan

    if (-not (Test-Path $JsonPath)) {
        Write-Host "[$message]:  " -NoNewline
        Write-Host "❌ JSON file not found at path: $JsonPath" -ForegroundColor Red
        return
    }

    $jsonContent = Get-Content $JsonPath -Raw | ConvertFrom-Json

    if (-not $jsonContent.Settings -or $jsonContent.Settings.Count -eq 0) {
        Write-Host "[$message]:  " -NoNewline
        Write-Host "⚠️ No 'Settings' section found in the JSON file." -ForegroundColor Yellow
        return
    }

    $settings = $jsonContent.Settings[0]

    $externalUserLifecycleAction = $settings.externalUserLifecycleAction
    $duration = $settings.durationUntilExternalUserDeletedAfterBlocked

    if (-not $externalUserLifecycleAction) {
        Write-Host "[$message]:  " -NoNewline
        Write-Host "⚠️ Missing 'externalUserLifecycleAction' in Settings." -ForegroundColor Yellow
        return
    }

    if ($externalUserLifecycleAction -eq 'blockSignInAndDelete' -and (-not $duration)) {
        Write-Host "[$message]:  " -NoNewline
        Write-Host "⚠️ Duration must be set when action is 'blockSignInAndDelete'." -ForegroundColor Yellow
        return
    }

    switch ($externalUserLifecycleAction) {
        'none'         { $duration = 0 }
        'blockSignIn'  { $duration = 0 }
        'blockSignInAndDelete' {
            if (-not ($duration -as [int])) {
                Write-Host "[$message]:  " -NoNewline
                Write-Host "⚠️ Invalid duration value: '$duration'. It must be an integer." -ForegroundColor Yellow
                return
            }
        }
        default {
            Write-Host "[$message]:  " -NoNewline
            Write-Host "⚠️ Unsupported value for externalUserLifecycleAction: '$externalUserLifecycleAction'" -ForegroundColor Yellow
            return
        }
    }

    $timespan = [System.TimeSpan]::FromDays([int]$duration)

    if (-not (Get-Module -Name Microsoft.Graph.Identity.Governance)) {
        Import-Module Microsoft.Graph.Identity.Governance
    }
    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes "EntitlementManagement.ReadWrite.All" -NoWelcome
    }

    Write-Host "[$message]:  " -NoNewline
    Write-Host "➕ Setting 'externalUserLifecycleAction' to '$externalUserLifecycleAction'" -ForegroundColor Gray
    Write-Host "[$message]:  " -NoNewline
    Write-Host "➕ Setting 'durationUntilExternalUserDeletedAfterBlocked' to '$duration'" -ForegroundColor Gray

    Update-MgEntitlementManagementSetting -ExternalUserLifecycleAction $externalUserLifecycleAction -DurationUntilExternalUserDeletedAfterBlocked $timespan | Out-Null

    Write-Host "[$message]: " -NoNewline
    Write-Host "🏁 Entitlement Management settings updated successfully." -ForegroundColor Green

    if ($EnableLogs) {
        Stop-Transcript
    }
}
catch {
    Write-Error "$message $_"
    if ($EnableLogs) {
        Stop-Transcript
    }
}