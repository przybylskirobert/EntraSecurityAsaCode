<#
.EXAMPLE
./New-EntraIDLCWSetup.ps1 -WorkflowScheduleIntervalInHours 1 -SenderDomain "mvp.entrablog.com" -UseCompanyBranding $false
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [int32] $WorkflowScheduleIntervalInHours,
    [Parameter(Mandatory = $true)]
    [string] $SenderDomain,
    [Parameter(Mandatory = $true)]
    [bool] $UseCompanyBranding,
    [switch] $WhatIf,
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
    $message = "[$($MyInvocation.MyCommand.Name)]: "
    if (-not (Get-Module -Name Microsoft.Graph.Identity.Governance)) {
        Import-Module Microsoft.Graph.Identity.Governance
    }
    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes "LifecycleWorkflows.ReadWrite.All" -NoWelcome
    }

    $params = @{
        "@odata.context" = "https://graph.microsoft.com/v1.0/$metadata#identityGovernance/lifecycleWorkflows/settings/$entity"
        workflowScheduleIntervalInHours = $workflowScheduleIntervalInHours
        emailSettings = @{
            senderDomain = $SenderDomain
            useCompanyBranding = $UseCompanyBranding
        }
    }
    if ($WhatIf){
        Update-MgIdentityGovernanceLifecycleWorkflowSetting -BodyParameter $params -WhatIf
    } else {
        try {
            Update-MgIdentityGovernanceLifecycleWorkflowSetting -BodyParameter $params
            Write-Host "$message Lifecycle Workflow Settings configured properly to:" -ForegroundColor Cyan
            $params
        }
        catch {
            Write-Error "$message Failed to configure LifecycleWorkflow settings: $_" 
        }
    }

    if ($EnableLogs) {
        Stop-Transcript
    }
}
catch {
    Write-Error $_
}


