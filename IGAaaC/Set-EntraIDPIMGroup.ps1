param (
    [Parameter(Mandatory)]
    [string]$JsonPath,
    [Parameter(Mandatory = $false)]
    [switch] $UsePrefix,
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
    $message = $MyInvocation.MyCommand.Name

    if ($Prefix) {
        $customPrefix = "$Prefix - "
    }
    else {
        $customPrefix = $null
    } 
    if (-not (Get-Module Microsoft.Graph.Identity.Governance)) {
        Import-Module Microsoft.Graph.Identity.Governance -ErrorAction Stop
    }

    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes "RoleManagement.ReadWrite.Directory", "Directory.AccessAsUser.All, Group.ReadWrite.All" -NoWelcome
    }

    function Ensure-GroupExists {
        param (
            [string]$DisplayName
        )
        $existingGroup = Get-MgGroup -Filter "displayName eq '$DisplayName'" -ErrorAction SilentlyContinue
        if ($existingGroup) {
            Write-Host "[$message]:    " -NoNewline
            Write-Host "ℹ️  Group '$DisplayName' already exists." -ForegroundColor Yellow
            return $existingGroup.Id
        }
        else {
            Write-Host "[$message]:    " -NoNewline
            Write-Host "✅ Creating group '$DisplayName'." -ForegroundColor Green
            $group = New-MgGroup -DisplayName $DisplayName -MailEnabled:$false -MailNickname $DisplayName.Replace(" ", "") -SecurityEnabled:$true -IsAssignableToRole:$false
            return $group.Id
        }
    }

    $jsonContent = Get-Content -Path $JsonPath | ConvertFrom-Json
    $groups = $jsonContent.PIMGroups

    $activationMaxDurationInHours = $jsonContent.AssignmentPolicy.ActivationMaxDurationInHours
    $expireEligibleAssignmentsAfterDays = $jsonContent.AssignmentPolicy.ExpireEligibleAssignmentsAfterDays
    $expireActiveAssignmentsAfterDays = $jsonContent.AssignmentPolicy.ExpireActiveAssignmentsAfterDays
    $requireMFAOnActiveAssignement = $jsonContent.AssignmentPolicy.RequireMFAOnActiveAssignement
    $requireJustificationOnActiveAssignement = $jsonContent.AssignmentPolicy.RequireJustificationOnActiveAssignement
    $requireMFAOnActivation = $jsonContent.AssignmentPolicy.RequireMFAOnActivation
    $requireJustificationOnActivation = $jsonContent.AssignmentPolicy.RequireJustificationOnActivation
    $requireApprovalOnActivation = $jsonContent.AssignmentPolicy.RequireApprovalOnActivation

    Write-Host "[$message]: " -nonewline
    Write-Host "🚀 Starting configuration of PIM Groups" -ForegroundColor Cyan

    foreach ($group in $groups) {
        Write-Host "[$message]:  " -nonewline
        Write-Host "➕ Working on PIM Group '$group'" -ForegroundColor Green
        $groupName = $customPrefix + $group
        $mainGroupId = Ensure-GroupExists -DisplayName $groupName
        $eligibleGroupName = $customPrefix + "$group - Eligible"
        $eligibleId = Ensure-GroupExists -DisplayName $eligibleGroupName
        $approversGroupName = $customPrefix + "$group - Approvers"
        $approversId = Ensure-GroupExists -DisplayName $approversGroupName
        $policies = Get-MgPolicyRoleManagementPolicyAssignment -Filter "scopeId eq '$mainGroupId' and scopeType eq 'Group' and roleDefinitionId eq 'member'"

        $Enablement_Admin_Assignment = $null
        if ($RequireMFAOnActiveAssignement -eq $true) {
            $Enablement_Admin_Assignment = "MultiFactorAuthentication"
        }

        if ($RequireJustificationOnActiveAssignement -eq $true) {
            if ($null -eq $Enablement_Admin_Assignment) {
                $Enablement_Admin_Assignment = "Justification"
            }
            if ($Enablement_Admin_Assignment -eq "MultiFactorAuthentication") {
                $Enablement_Admin_Assignment = $Enablement_Admin_Assignment + "," + "Justification"
                $Enablement_Admin_Assignment = [system.array]($Enablement_Admin_Assignment -split ",")
            }
        }

        $Enablement_EndUser_Assignment = @()
        if ($RequireMFAOnActivation -eq $true) {
            $Enablement_EndUser_Assignment += "MultiFactorAuthentication"
        }

        if ($RequireJustificationOnActivation -eq $true) {
            $Enablement_EndUser_Assignment += "Justification"
        }

        if ($RequireTicketInfoOnActivation -eq $true) {
            $Enablement_EndUser_Assignment += "Ticketing"
        }

        $Enablement_EndUser_Assignment = $Enablement_EndUser_Assignment | Select-Object -Unique
        $Enablement_EndUser_Assignment = [Object[]]$Enablement_EndUser_Assignment
    
        $existingAssignment = Get-MgIdentityGovernancePrivilegedAccessGroupEligibilityScheduleInstance -Filter "groupId eq '$mainGroupID'" 

        if ($existingAssignment) {
            Write-Host "[$message]:    " -NoNewline
            Write-Host "ℹ️  Eligibility assignment already exists for group '$mainGroupID'." -ForegroundColor Yellow
        }
        else {
            $params = @{
                accessId      = "member"
                principalId   = $eligibleId
                groupId       = $mainGroupId
                action        = "AdminAssign"
                scheduleInfo  = @{
                    startDateTime = (Get-Date)
                    "Expiration"  = @{
                        "Type"     = "AfterDuration"
                        "Duration" = $expireEligibleAssignmentsAfterDays
                    }
                }
                justification = "Assign eligible request."
            }
            New-MgIdentityGovernancePrivilegedAccessGroupEligibilityScheduleRequest -BodyParameter $params | Out-Null
            Write-Host "[$message]:    " -NoNewline
            Write-Host "✅ Eligibility schedule request submitted for group '$mainGroupID'." -ForegroundColor Green
        }

        $params = @{
            rules = @(
                @{
                    "@odata.type"        = "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule"
                    id                   = "Expiration_EndUser_Assignment"
                    isExpirationRequired = $true
                    maximumDuration      = "PT4H"
                    target               = @{
                        caller              = "EndUser"
                        operations          = @("All")
                        level               = "Assignment"
                        inheritableSettings = @()
                        enforcedSettings    = @()
                    }
                },
                @{
                    "@odata.type"        = "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule"
                    id                   = "Expiration_Admin_Eligibility"
                    isExpirationRequired = $true
                    maximumDuration      = $expireEligibleAssignmentsAfterDays
                    target               = @{
                        caller              = "Admin"
                        operations          = @("All")
                        level               = "Eligibility"
                        inheritableSettings = @()
                        enforcedSettings    = @()
                    }
                },
                @{
                    "@odata.type"        = "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule"
                    id                   = "Expiration_Admin_Assignment"
                    isExpirationRequired = $true
                    maximumDuration      = $expireActiveAssignmentsAfterDays
                    target               = @{
                        caller              = "Admin"
                        operations          = @("All")
                        level               = "Assignment"
                        inheritableSettings = @()
                        enforcedSettings    = @()
                    }
                },
                @{
                    "@odata.type"  = "#microsoft.graph.unifiedRoleManagementPolicyEnablementRule"
                    "id"           = "Enablement_Admin_Assignment"
                    "enabledRules" = @($Enablement_Admin_Assignment)
                    "target"       = @{
                        "caller"              = "Admin"
                        "operations"          = @(
                            "all"
                        )
                        "level"               = "Assignment"
                        "inheritableSettings" = @()
                        "enforcedSettings"    = @()
                    }
                },
                @{
                    "@odata.type"  = "#microsoft.graph.unifiedRoleManagementPolicyEnablementRule"
                    "id"           = "Enablement_EndUser_Assignment"
                    "enabledRules" = @($Enablement_EndUser_Assignment)
                    "target"       = @{
                        "caller"              = "Admin"
                        "operations"          = @(
                            "all"
                        )
                        "level"               = "Assignment"
                        "inheritableSettings" = @()
                        "enforcedSettings"    = @()
                    }
                },
                @{
                    "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyApprovalRule"
                    "id"          = "Approval_EndUser_Assignment"
                    "target"      = @{
                        "caller"              = "EndUser"
                        "operations"          = @("all")
                        "level"               = "Assignment"
                        "inheritableSettings" = @()
                        "enforcedSettings"    = @()
                    }
                    "setting"     = @{
                        "isApprovalRequired"               = $true
                        "isApprovalRequiredForExtension"   = $false
                        "isRequestorJustificationRequired" = $true
                        "approvalMode"                     = "SingleStage"
                        "approvalStages"                   = @(
                            @{
                                "approvalStageTimeOutInDays"      = 1
                                "isApproverJustificationRequired" = $true
                                "escalationTimeInMinutes"         = 0
                                "isEscalationEnabled"             = $false
                                "primaryApprovers"                = @(
                                    @{
                                        "@odata.type" = "#microsoft.graph.groupMembers"
                                        "groupID"     = $approversId
                                        "description" = $null
                                    }
                                )
                                "escalationApprovers"             = @()
                            }
                        )
                    }
                }
            )
        }
        Write-Host "[$message]:    " -nonewline
        Write-Host "➕ Configuring 'Expiration_EndUser_Assignment' to '$activationMaxDurationInHours'" -ForegroundColor Green
        Write-Host "[$message]:    " -nonewline
        Write-Host "➕ Configuring 'Expiration_Admin_Eligibility' to '$ExpireEligibleAssignmentsAfterDays'" -ForegroundColor Green
        Write-Host "[$message]:    " -nonewline
        Write-Host "➕ Configuring 'Expiration_Admin_Assignment' to '$ExpireActiveAssignmentsAfterDays'" -ForegroundColor Green
        Write-Host "[$message]:    " -nonewline
        Write-Host "➕ Configuring 'Enablement_Admin_Assignment' to '$Enablement_Admin_Assignment'" -ForegroundColor Green
        Write-Host "[$message]:    " -nonewline
        Write-Host "➕ Configuring 'Enablement_EndUser_Assignment' to '$Enablement_EndUser_Assignment'" -ForegroundColor Green
        Write-Host "[$message]:    " -NoNewline
        Write-Host "➕ Configuring role approvers to '$approversGroupName'" -ForegroundColor Green
        Write-Host "[$message]:    " -NoNewline
        Write-Host "➕ Configuring role eligibility for '$eligibleGroupName'" -ForegroundColor Green
        Update-MgPolicyRoleManagementPolicy -UnifiedRoleManagementPolicyId $policies.PolicyId -BodyParameter $params | out-null
        Write-Host "[$message]:  " -nonewline
        Write-Host "✅ PIM Group '$group' setup completed." -ForegroundColor Green
    }

    Write-Host "[$message]: " -nonewline
    Write-Host "🏁  Configuration Completed." -ForegroundColor Cyan
    if ($EnableLogs) {
        Stop-Transcript
    }
}
catch {
    Write-Error $_
}
