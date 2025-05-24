[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string] $JsonPath,
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

    $json = Get-Content -Path $JsonPath -Raw | ConvertFrom-Json
    $policy = $json.AssignmentPolicy
    $roles = $json.PIMRoles

    $activationMaxDurationInHours = $policy.ActivationMaxDurationInHours
    $expireEligibleAssignmentsAfterDays = $policy.ExpireEligibleAssignmentsAfterDays
    $expireActiveAssignmentsAfterDays = $policy.ExpireActiveAssignmentsAfterDays
    $requireMFAOnActiveAssignement = $policy.RequireMFAOnActiveAssignement
    $requireJustificationOnActiveAssignement = $policy.RequireJustificationOnActiveAssignement
    $requireMFAOnActivation = $policy.RequireMFAOnActivation
    $requireJustificationOnActivation = $policy.RequireJustificationOnActivation
    $requireApprovalOnActivation = $policy.RequireApprovalOnActivation
    Write-Host "[$message]: " -nonewline
    Write-Host "🚀 Starting configuration of PIM Roles" -ForegroundColor Cyan

    foreach ($role in $roles){
        
        Write-Host "[$message]:  " -nonewline
        Write-Host "➕ Working on role '$role'" -ForegroundColor Green
        $roleName = $role
        $roleID = (Get-MgRoleManagementDirectoryRoleDefinition | where-Object { $_.DisplayName -eq $roleName }).Id
        $policyRoleIDsArray = Get-MgPolicyRoleManagementPolicyAssignment -Filter "scopeId eq '/' and scopeType eq 'Directory'"
        $policyRoleID = ($policyRoleIDsArray | where-Object { $_.RoleDefinitionId -eq $roleID }).PolicyId

        $params = @{
            "@odata.type"          = "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule"
            "id"                   = "Expiration_EndUser_Assignment"
            "isExpirationRequired" = $true
            "maximumDuration"      = $activationMaxDurationInHours
            "target"               = @{
                "caller"              = "EndUser"
                "operations"          = @(
                    "all"
                )
                "level"               = "Assignment"
                "inheritableSettings" = @()
                "enforcedSettings"    = @()
            }
        }
        Write-Host "[$message]:    " -nonewline
        Write-Host "➕ Configuring 'Expiration_EndUser_Assignment' to '$activationMaxDurationInHours'" -ForegroundColor Yellow
        Update-MgPolicyRoleManagementPolicyRule -UnifiedRoleManagementPolicyId $policyRoleID -UnifiedRoleManagementPolicyRuleId Expiration_EndUser_Assignment -BodyParameter $params | Out-Null

        if ($ExpireEligibleAssignmentsAfterDays ) {
            $params = @{
                "@odata.type"          = "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule"
                "id"                   = "Expiration_Admin_Eligibility"
                "isExpirationRequired" = $true
                "maximumDuration"      = $ExpireEligibleAssignmentsAfterDays
                "target"               = @{
                    "caller"              = "Admin"
                    "operations"          = @(
                        "all"
                    )
                    "level"               = "Eligibility"
                    "inheritableSettings" = @()
                    "enforcedSettings"    = @()
                }
            }
            Write-Host "[$message]:    " -nonewline
            Write-Host "➕ Configuring 'Expiration_Admin_Eligibility' to '$ExpireEligibleAssignmentsAfterDays'" -ForegroundColor Yellow
            Update-MgPolicyRoleManagementPolicyRule -UnifiedRoleManagementPolicyId $policyRoleID -UnifiedRoleManagementPolicyRuleId Expiration_Admin_Eligibility -BodyParameter $params | Out-Null
        }

        if ($ExpireActiveAssignmentsAfterDays ) {
            $params = @{
                "@odata.type"          = "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule"
                "id"                   = "Expiration_Admin_Assignment"
                "isExpirationRequired" = $true
                "maximumDuration"      = $ExpireActiveAssignmentsAfterDays
                "target"               = @{
                    "caller"              = "Admin"
                    "operations"          = @(
                        "all"
                    )
                    "level"               = "Assignment"
                    "inheritableSettings" = @()
                    "enforcedSettings"    = @()
                }
            }
            Write-Host "[$message]:    " -nonewline
            Write-Host "➕ Configuring 'Expiration_Admin_Assignment' to '$ExpireActiveAssignmentsAfterDays'" -ForegroundColor Yellow
            Update-MgPolicyRoleManagementPolicyRule -UnifiedRoleManagementPolicyId $policyRoleID -UnifiedRoleManagementPolicyRuleId Expiration_Admin_Assignment -BodyParameter $params  | Out-Null
        }

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

        if ($Enablement_Admin_Assignment) {
            $params = @{
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
            }
            Write-Host "[$message]:    " -nonewline
            Write-Host "➕ Configuring 'Enablement_Admin_Assignment' to '$Enablement_Admin_Assignment'" -ForegroundColor Yellow
            Update-MgPolicyRoleManagementPolicyRule -UnifiedRoleManagementPolicyId $policyRoleID -UnifiedRoleManagementPolicyRuleId Enablement_Admin_Assignment -BodyParameter $params | Out-Null
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

        if ($Enablement_EndUser_Assignment) {
            $params = @{            "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyEnablementRule"
                "id"                              = "Enablement_EndUser_Assignment"
                "enabledRules"                    = @($Enablement_EndUser_Assignment)
                "target"                          = @{
                    "caller"              = "Admin"
                    "operations"          = @(
                        "all"
                    )
                    "level"               = "Assignment"
                    "inheritableSettings" = @()
                    "enforcedSettings"    = @()
                }
            }
            Write-Host "[$message]:    " -nonewline
            Write-Host "➕ Configuring 'Enablement_EndUser_Assignment' to '$Enablement_EndUser_Assignment'" -ForegroundColor Yellow
            Update-MgPolicyRoleManagementPolicyRule -UnifiedRoleManagementPolicyId $policyRoleID -UnifiedRoleManagementPolicyRuleId Enablement_EndUser_Assignment -BodyParameter $params | out-null
        }

if ($RequireApprovalOnActivation) {
    $pimApproversGroupName = $customPrefix + "PIM $roleName - Approvers"
    $groupDescription = "Group with approvers for role '$roleName' in PIM"
    Write-Host "[$message]:    " -NoNewline
    Write-Host "➕ Configuring role approvers to '$pimApproversGroupName'" -ForegroundColor Yellow

    try {
        Write-Host "[$message]:      " -NoNewline
        Write-Host "🔍 Checking if the group '$pimApproversGroupName' exists in Microsoft Entra ID." -ForegroundColor Gray
        $approversGroup = Get-MgGroup -Filter "displayName eq '$pimApproversGroupName'" -ErrorAction SilentlyContinue

        if ($approversGroup) {
            Write-Host "[$message]:        " -NoNewline
            Write-Host "ℹ️  Group '$pimApproversGroupName' already exists." -ForegroundColor Gray
        } else {
            Write-Host "[$message]:        " -NoNewline
            Write-Host "➕ Creating group '$pimApproversGroupName'." -ForegroundColor Gray
            $approversGroup = New-MgGroup -DisplayName $pimApproversGroupName -MailEnabled:$false -MailNickname $pimApproversGroupName.Replace(" ", "") -SecurityEnabled:$true -Description $groupDescription
            Write-Host "[$message]:        " -NoNewline
            Write-Host "✅ Group '$pimApproversGroupName' created." -ForegroundColor Yellow
        }

        $approvalRule = Get-MgPolicyRoleManagementPolicyRule -UnifiedRoleManagementPolicyId $policyRoleID -UnifiedRoleManagementPolicyRuleId "Approval_EndUser_Assignment" #-ErrorAction SilentlyContinue
        $alreadyApprover = $approvalRule.AdditionalProperties.setting.approvalStages.primaryApprovers.groupId -contains $approversGroup.Id
        if ($alreadyApprover) {
            Write-Host "[$message]:        " -NoNewline
            Write-Host "ℹ️  Group '$pimApproversGroupName' is already set as approver. Skipping." -ForegroundColor Gray
        } else {
            $params = @{
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
                                    "groupID"     = $approversGroup.Id
                                    "description" = $groupDescription 
                                }
                            )
                            "escalationApprovers"             = @()
                        }
                    )
                }
            }
            Write-Host "[$message]:        " -NoNewline
            Write-Host "➕ Group '$pimApproversGroupName' set as approver." -ForegroundColor Yellow
            Update-MgPolicyRoleManagementPolicyRule -UnifiedRoleManagementPolicyId $policyRoleID -UnifiedRoleManagementPolicyRuleId "Approval_EndUser_Assignment" -BodyParameter $params | Out-Null
        }
        Write-Host "[$message]:      " -NoNewline
        Write-Host "✅ Approver setup completed." -ForegroundColor Yellow
    }
    catch {
        Write-Host "[$message]:        " -NoNewline
        Write-Host "❌ Error checking/assigning approvers: $_" -ForegroundColor Red
    }

    $pimEligibleGroupName = $customPrefix + "PIM $roleName - Eligible"
    $eligibleGroupDescription = "Group eligible for '$roleName' in PIM requests."
    Write-Host "[$message]:    " -NoNewline
    Write-Host "➕ Configuring role eligibility for '$pimEligibleGroupName'" -ForegroundColor Yellow

    try {
        Write-Host "[$message]:      " -NoNewline
        Write-Host "🔍 Checking if group '$pimEligibleGroupName' exists." -ForegroundColor Gray
        $eligibleGroup = Get-MgGroup -Filter "displayName eq '$pimEligibleGroupName'" -ErrorAction SilentlyContinue

        if ($eligibleGroup) {
            Write-Host "[$message]:        " -NoNewline
            Write-Host "ℹ️  Group '$pimEligibleGroupName' already exists." -ForegroundColor Gray
        } else {
            $eligibleGroup = New-MgGroup -DisplayName $pimEligibleGroupName -MailEnabled:$false -MailNickname $pimEligibleGroupName.Replace(" ", "") -SecurityEnabled:$true -Description $eligibleGroupDescription -IsAssignableToRole:$true
            Write-Host "[$message]:        " -NoNewline
            Write-Host "✅ Group '$pimEligibleGroupName' created." -ForegroundColor Yellow
        }
        $existingEligibility = Get-MgRoleManagementDirectoryRoleEligibilityScheduleRequest -Filter "principalId eq '$($eligibleGroup.Id)' and roleDefinitionId eq '$roleId'" -ErrorAction SilentlyContinue
        if (($existingEligibility).count -ge 1) {
            Write-Host "[$message]:        " -NoNewline
            Write-Host "ℹ️  Group '$pimEligibleGroupName' is already assigned as eligible. Skipping." -ForegroundColor Gray
        } else {
            $params = @{
                "PrincipalId"      = "$($eligibleGroup.Id)"
                "RoleDefinitionId" = "$roleid"
                "Justification"    = "Add eligible assignment"
                "DirectoryScopeId" = "/"
                "Action"           = "AdminAssign"
                "ScheduleInfo"     = @{
                    "StartDateTime" = (Get-Date)
                    "Expiration"    = @{
                        "Type"     = "AfterDuration"
                        "Duration" = "P180D"
                    }
                }
            }
            New-MgRoleManagementDirectoryRoleEligibilityScheduleRequest -BodyParameter $params | Out-Null
        }
        Write-Host "[$message]:      " -NoNewline
        Write-Host "✅ Eligibility setup completed." -ForegroundColor Yellow
    }
    catch {
            Write-Host "[$message]:        " -NoNewline
            Write-Host "❌ Error in eligible group assignment: $_" -ForegroundColor Red
    }
}
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
