<#
.EXAMPLE

.EXAMPLE
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string] $WorkflowName,
    [Parameter(Mandatory = $true)]
    [string[]] $IncludedSubjects ,
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
        Connect-MgGraph -Scopes "LifecycleWorkflows.ReadWrite.All","User.Read.All", "Group.Read.All" -NoWelcome
    }

    function New-SubjectsParamsFromUsersOrGroups {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string[]] $IncludedSubjects
        )
        $userIds = New-Object System.Collections.Generic.HashSet[string]
        foreach ($subject in $IncludedSubjects) {
            if ([string]::IsNullOrWhiteSpace($subject)) { continue }
            try {
                $guid = [Guid]::Empty
                $isGuid = [Guid]::TryParse($subject, [ref]$guid)
                if ($isGuid) {
                    try {
                        $u = Get-MgUser -UserId $subject -Property Id -ErrorAction Stop
                        [void]$userIds.Add($u.Id)
                        continue
                    } catch {}
                    $g = Get-MgGroup -GroupId $subject -Property Id -ErrorAction Stop
                    $members = Get-MgGroupMember -GroupId $g.Id -All -Property Id,'@odata.type'
                    foreach ($m in $members) {
                        if ($m.AdditionalProperties['@odata.type'] -eq '#microsoft.graph.user') {
                            [void]$userIds.Add([string]$m.Id)
                        }
                    }
                    continue
                }
                if ($subject -match '@') {
                    $u = Get-MgUser -UserId $subject -Property Id -ErrorAction Stop
                    [void]$userIds.Add($u.Id)
                    continue
                }
                $group = Get-MgGroup -Filter "displayName eq '$subject'" -Property Id,DisplayName
                if (-not $group) {
                    $u = Get-MgUser -UserId $subject -Property Id -ErrorAction Stop
                    [void]$userIds.Add($u.Id)
                    continue
                }
                if ($group.Count -gt 1) {
                    throw "Group name '$subject' is not unique. Use GroupId (GUID) or a unique displayName."
                }
                $members = Get-MgGroupMember -GroupId $group.Id -All -Property Id
                foreach ($m in $members) {
                    if ($m.AdditionalProperties['@odata.type'] -eq '#microsoft.graph.user') {
                        [void]$userIds.Add([string]$m.Id)
                    }
                }
            }
            catch {
                throw "Failed to resolve '$subject' as user or group in Entra ID. Error: $($_.Exception.Message)"
            }
        }
        $subjects = foreach ($id in $userIds) { @{ id = $id } }
        return @{
            subjects = @($subjects)
        }
    }    
    $params = New-SubjectsParamsFromUsersOrGroups -IncludedSubjects $IncludedSubjects
    $params = $params  | ConvertTo-Json -Depth 10
    $params

$workflowID = (Get-MgIdentityGovernanceLifecycleWorkflow | Where-Object {$_.DisplayName -eq $WorkflowName} -ErrorAction SilentlyContinue).Id 
    if ($workflowID -ne $null){
        if ($WhatIf){
            Initialize-MgIdentityGovernanceLifecycleWorkflow -WorkflowId $workflowID -BodyParameter $params -WhatIf
        } else {
                try {
                    Initialize-MgIdentityGovernanceLifecycleWorkflow -WorkflowId $workflowID -BodyParameter $params
                    Write-Host "$message Triggering Lifecycle Workflow '$WorkflowName' for the following users" -ForegroundColor Cyan
                    $stringUsers = $IncludedSubjects -join ', '
                    Write-Host "$message $stringUsers" -ForegroundColor Cyan
                }
                catch {
                    Write-Error "$message Failed to trigger Lifecycle Workflow: $_" 
                }
        }
    } else {
        Write-Host "$message Lifecycle Workflow '$WorkflowName' does not exists in tenant" -ForegroundColor Red
    }

    if ($EnableLogs) {
        Stop-Transcript
    }
}
catch {
    Write-Error $_
}


