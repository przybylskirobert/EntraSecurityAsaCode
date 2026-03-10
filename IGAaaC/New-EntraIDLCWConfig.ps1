<#
.EXAMPLE
./New-EntraIDLCWConfig.ps1 -WorkflowScheduleIntervalInHours 1 -SenderDomain "mvp.entrablog.com" -UseCompanyBranding $false

.EXAMPLE
./New-EntraIDLCWConfig.ps1 -WorkflowScheduleIntervalInHours 1 -SenderDomain "mvp.entrablog.com" -UseCompanyBranding $false -WhatIF

#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string] $DisplayName,
    [Parameter(Mandatory = $true)]
    [string] $Rule,
    [Parameter(Mandatory = $true)]
    [string] $TimeBasedAttribute,
    [Parameter(Mandatory = $true)]
    [int] $OffsetInDays,
    [Parameter(Mandatory = $false)]  
    [string] $Template,
    [Parameter(Mandatory = $false)]
    [bool] $WhatIf,
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

    $params = @()
    $params = Get-Content -Path ".\ReferenceTasks\$Template.json" -Raw
    $params = $params -replace "\[displayName\]", $DisplayName
    $params = $params -replace "\[description\]", $DisplayName
    $params = $params -replace "\[rule\]", $rule
    $params = $params -replace "\[timeBasedAttribute\]", $timeBasedAttribute
    $params = $params -replace "\[offsetInDays\]", $OffsetInDays

    if ($WhatIf){
        New-MgIdentityGovernanceLifecycleWorkflow -BodyParameter $params -WhatIf
    } else {
        if ((Get-MgIdentityGovernanceLifecycleWorkflow | Where-Object {$_.DisplayName -eq $DisplayName}) -eq $null){
            try {
                New-MgIdentityGovernanceLifecycleWorkflow -BodyParameter $params
                Write-Host "$message Creating new Lifecycle Workflow '$DisplayName'" -ForegroundColor Cyan
            }
            catch {
                Write-Error "$message Failed to configure Lifecycle Workflow: $_" 
            }
        } else {
            Write-Host "$message Lifecycle Workflow '$DisplayName' already exists." -ForegroundColor Red
        }
    }
    if ($EnableLogs) {
        Stop-Transcript
    }
}
catch {
    Write-Error $_
}


