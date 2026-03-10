<#
    .EXAMPLE
        Set-EntraIDELMSettings.ps1 -externalUserLifecycleAction blockSignInAndDelete -DurationUntilExternalUserDeletedAfterBlocked 25 -EnableLogs
    .EXAMPLE
        Set-EntraIDELMSettings.ps1 -externalUserLifecycleAction blockSignInAndDelete -DurationUntilExternalUserDeletedAfterBlocked 25
    .EXAMPLE
        Set-EntraIDELMSettings.ps1 -externalUserLifecycleAction none -DurationUntilExternalUserDeletedAfterBlocked 25 -EnableLogs
    .EXAMPLE
        Set-EntraIDELMSettings.ps1 -externalUserLifecycleAction blockSignIn -DurationUntilExternalUserDeletedAfterBlocked 25 -EnableLogs

#>

param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("none", "blockSignIn", "blockSignInAndDelete")]    
    [string]$ExternalUserLifecycleAction,

    [Parameter(Mandatory = $false)]
    [string]$DurationUntilExternalUserDeletedAfterBlocked,

    [Parameter(Mandatory = $false)]    
    [switch] $EnableLogs
)
try {
    if ($EnableLogs) {
        $scriptPath = $MyInvocation.MyCommand.Path
        $scriptDir = Split-Path -Path $scriptPath
        $scriptDir = $scriptDir + "/Logs"
        $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($scriptPath)
        $dateTime = (Get-Date).ToString("yyyy_MM-dd HH_mm_ss")
        $logFileName = "$scriptName`_$dateTime.log"
        $logFilePath = Join-Path -Path $scriptDir -ChildPath $logFileName
        Start-Transcript -Path $logFilePath -NoClobber -UseMinimalHeader -Append -Force
    }

    $output = @(
        $(New-Object PSObject -Property @{
                ExternalUserLifecycleAction                  = $ExternalUserLifecycleAction; 
                DurationUntilExternalUserDeletedAfterBlocked = $DurationUntilExternalUserDeletedAfterBlocked ; 
                EnableLogs                                   = $EnableLogs
            }
        )
    )
    $message = "[$($MyInvocation.MyCommand.Name)]: "
    if (-not (Get-Module -Name Microsoft.Graph.Identity.Governance)) {
        Import-Module Microsoft.Graph.Identity.Governance
    }
    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes "EntitlementManagement.ReadWrite.All" -NoWelcome
    }

    switch ($ExternalUserLifecycleAction) {
        'blockSignInAndDelete' {
            if (-not $DurationUntilExternalUserDeletedAfterBlocked) {
                throw "$message When ExternalUserLifecycleAction is 'blockSignInAndDelete', you must provide a valid DurationUntilExternalUserDeletedAfterBlocked."
            }
        }
        'none' {
            $DurationUntilExternalUserDeletedAfterBlocked = '0'
        }
        'blockSignIn' {
            $DurationUntilExternalUserDeletedAfterBlocked = '0'
        }
    }
    $timespan = [System.TimeSpan]::FromDays($DurationUntilExternalUserDeletedAfterBlocked)

    try {
        Write-Host "$message Configuring Block external user from signing in to this directory to '$ExternalUserLifecycleAction' " -ForegroundColor Cyan
        Write-Host "$message Configuring Number of days before removing external user from this directory to '$DurationUntilExternalUserDeletedAfterBlocked' " -ForegroundColor Cyan
        Update-MgEntitlementManagementSetting -ExternalUserLifecycleAction $ExternalUserLifecycleAction -DurationUntilExternalUserDeletedAfterBlocked $timespan |Out-Null
        Write-Host "$message Entitlement Management settings updated successfully." -ForegroundColor Green
        $OUTPUT
    }
    catch {
        Write-Error "$message Failed to configure Entitlement Management settings: $_"
    }

    if ($EnableLogs) {
        Stop-Transcript
    }
}
catch {
    Write-Error $_
}