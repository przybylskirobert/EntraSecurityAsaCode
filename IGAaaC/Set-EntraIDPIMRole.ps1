param (
    [Parameter(Mandatory = $true)]
    [string] $RoleName,

    [ValidateSet("PT30M", "PT1H", "PT1H30M", "PT2H", "PT2H30M", "PT3H", "PT3H30M", "PT4H", "PT4H30M", "PT5H", "PT5H30M", "PT6H", "PT6H30M", "PT7H", "PT7H30M", "PT8H", "PT8H30M", "PT9H", "PT9H30M", "PT10H", "PT10H30M", "PT11H", "PT11H30M", "PT12H", "PT12H30M", "PT13H", "PT13H30M", "PT14H", "PT14H30M", "PT15H", "PT15H30M", "PT16H", "PT16H30M", "PT17H", "PT17H30M", "PT18H", "PT18H30M", "PT19H", "PT19H30M", "PT20H")]
    [Parameter(Mandatory = $true)]
    [string] $ActivationMaxDurationInHours,

    [ValidateSet("P15D", "P30D", "P90D", "P180D", "P365D")]
    [string] $ExpireEligibleAssignmentsAfterDays,

    [ValidateSet("P15D", "P30D", "P90D", "P180D", "P365D")]
    [string] $ExpireActiveAssignmentsAfterDays,

    [switch] $RequireMFAOnActiveAssignement,

    [switch] $RequireJustificationOnActiveAssignement, 

    [switch] $RequireMFAOnActivation,

    [switch] $RequireJustificationOnActivation,

    [switch] $RequireTicketInfoOnActivation,

    [switch] $RequireApprovalOnActivation,

    [string] $Prefix,
    
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
                RoleName                                = $RoleName; 
                ActivationMaxDurationInHours            = $ActivationMaxDurationInHours ; 
                ExpireEligibleAssignmentsAfterDays      = $ExpireEligibleAssignmentsAfterDays; 
                ExpireActiveAssignmentsAfterDays        = $ExpireActiveAssignmentsAfterDays; 
                RequireMFAOnActiveAssignement           = $RequireMFAOnActiveAssignement;
                RequireJustificationOnActiveAssignement = $RequireJustificationOnActiveAssignement; 
                RequireMFAOnActivation                  = $RequireMFAOnActivation; 
                RequireJustificationOnActivation        = $RequireJustificationOnActivation;
                RequireTicketInfoOnActivation           = $RequireTicketInfoOnActivation; 
                RequireApprovalOnActivation             = $RequireApprovalOnActivation;
                Enabled                                 = $Enabled
            }
        )
    )
    $message = "[$($MyInvocation.MyCommand.Name)][Role: '$RoleName']: "

    if ($Prefix) {
        $customPrefix = "$Prefix - "
    }
    else {
        $customPrefix = $null
    } 

    if (-not (Get-Module Microsoft.Graph.Identity.Governance)) {
        Write-Host "[$message]: Importing Microsoft.Graph.Identity.Governance module..."
        Import-Module Microsoft.Graph.Identity.Governance -ErrorAction Stop
    }

    if (-not (Get-MgContext)) {
        Write-Host "[$message]: Connecting to Microsoft Graph..."
        Connect-MgGraph -Scopes "RoleManagement.ReadWrite.Directory", "Directory.AccessAsUser.All" -NoWelcome
    }

    $roleID = (Get-MgRoleManagementDirectoryRoleDefinition | where-Object { $_.DisplayName -eq $RoleNAme }).Id
    $policyRoleIDsArray = Get-MgPolicyRoleManagementPolicyAssignment -Filter "scopeId eq '/' and scopeType eq 'Directory'"
    $policyRoleID = ($policyRoleIDsArray | where-Object { $_.RoleDefinitionId -eq $roleID }).PolicyId

    $params = @{
        "@odata.type"          = "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule"
        "id"                   = "Expiration_EndUser_Assignment"
        "isExpirationRequired" = $true
        "maximumDuration"      = $ActivationMaxDurationInHours
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
    Write-Host "$message Configuring 'Expiration_EndUser_Assignment' to '$ActivationMaxDurationInHours'" -ForegroundColor Cyan
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
        Write-Host "$message Configuring 'Expiration_Admin_Eligibility' to '$ExpireEligibleAssignmentsAfterDays'" -ForegroundColor Cyan
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
        Write-Host "$message Configuring 'Expiration_Admin_Assignment' to '$ExpireActiveAssignmentsAfterDays'" -ForegroundColor Cyan
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
        Write-Host "$message Configuring 'Enablement_Admin_Assignment' to '$Enablement_Admin_Assignment'" -ForegroundColor Cyan
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
        Write-Host "$message Configuring 'Enablement_EndUser_Assignment' to '$Enablement_EndUser_Assignment'" -ForegroundColor Cyan
        Update-MgPolicyRoleManagementPolicyRule -UnifiedRoleManagementPolicyId $policyRoleID -UnifiedRoleManagementPolicyRuleId Enablement_EndUser_Assignment -BodyParameter $params | out-null
    }

    if ($RequireApprovalOnActivation) {
        $pimApproversGroupName = $customPrefix + "PIM $RoleName - Approvers"
        $groupDescription = "Group with approvers for role '$RoleName' in PIM"
        if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
            throw "$message The Microsoft Graph PowerShell module is not installed. Install it using 'Install-Module -Name Microsoft.Graph'."
        }
        try {
            if (-not (Get-MgContext)) {
                Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
                Connect-MgGraph -Scopes "Group.ReadWrite.All"
            }
        }
        catch {
            throw "$message Unable to connect to Microsoft Graph. Ensure you have the required permissions."
        }

        try {
            Write-Host "$message Checking if the group '$pimApproversGroupName' exists in Microsoft Entra ID..." -ForegroundColor Cyan
            $existingGroup = Get-MgGroup -Filter "displayName eq '$pimApproversGroupName'" -ErrorAction SilentlyContinue

            if ($null -ne $existingGroup) {
                Write-Host "$message Group '$pimApproversGroupName' already exists in Microsoft Entra ID." -ForegroundColor Cyan
                $groupID = $existingGroup.ID
            }
            else {
                Write-Host "$message Group '$pimApproversGroupName' does not exist. Creating a new group..." -ForegroundColor Cyan
                $group = New-MgGroup -DisplayName $pimApproversGroupName -MailEnabled:$false -MailNickname $pimApproversGroupName.Replace(" ", "") -SecurityEnabled:$true -Description $groupDescription
                $groupID = $group.ID
                do {
                    $existingGroup = Get-MgGroup -GroupId $groupID -ErrorAction SilentlyContinue
                    if (-not $existingGroup) {
                        Write-Host "$message Group not available yet. Waiting 5 seconds..."
                        Start-Sleep -Seconds 5
                    }
                } while (-not $existingGroup)
                Write-Host "$message Group '$pimApproversGroupName' created successfully with the description: '$groupDescription'." -ForegroundColor Cyan
            }
        }
        catch {
            Write-Host "$message An error occurred: $_" -ForegroundColor Red
        }

        $params = @{
            "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyApprovalRule"
            "id"          = "Approval_EndUser_Assignment"
            "target"      = @{
                "caller"              = "EndUser"
                "operations"          = @(
                    "all"
                )
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
                                "groupID"     = $groupID
                                "description" = $groupDescription 
                            }
                        )
                        "escalationApprovers"             = @()
                    }
                )
            }
        }
        Write-Host "$message Configuring 'Approval_EndUser_Assignment' to '$pimApproversGroupName'" -ForegroundColor Cyan
        Update-MgPolicyRoleManagementPolicyRule -UnifiedRoleManagementPolicyId $policyRoleID -UnifiedRoleManagementPolicyRuleId Approval_EndUser_Assignment -BodyParameter $params | Out-Null

        $pimEligibleGroupName = $customPrefix + "PIM $RoleName - Eligible"
        $pimEligiblegroupDescription = "Group eligible for '$RoleName' in PIM requests."
        if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
            throw "$message The Microsoft Graph PowerShell module is not installed. Install it using 'Install-Module -Name Microsoft.Graph'."
        }
        try {
            if (-not (Get-MgContext)) {
                Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
                Connect-MgGraph -Scopes "Group.ReadWrite.All"
            }
        }
        catch {
            throw "$message Unable to connect to Microsoft Graph. Ensure you have the required permissions."
        }
    
        try {
            Write-Host "$message Checking if the group '$pimEligibleGroupName' exists in Microsoft Entra ID..." -ForegroundColor Cyan
            $existingGroup = Get-MgGroup -Filter "displayName eq '$pimEligibleGroupName'" -ErrorAction SilentlyContinue
    
            if ($null -ne $existingGroup) {
                Write-Host "$message Group '$pimEligibleGroupName' already exists in Microsoft Entra ID." -ForegroundColor Cyan
                $groupID = $existingGroup.ID
            }
            else {
                Write-Host "$message Group '$pimEligibleGroupName' does not exist. Creating a new group..." -ForegroundColor Cyan
                $group = New-MgGroup -DisplayName $pimEligibleGroupName -MailEnabled:$false -MailNickname $pimApproversGroupName.Replace(" ", "") -SecurityEnabled:$true -Description $groupDescription -IsAssignableToRole:$true
                $groupID = $group.ID
                Write-Host "$message Group '$pimEligibleGroupName' created successfully with the description: '$groupDescription'." -ForegroundColor Cyan
            }
        }
        catch {
            Write-Host "$message An error occurred: $_" -ForegroundColor Red
        }

        $params = @{
            "PrincipalId"      = "$groupID"
            "RoleDefinitionId" = "$roleid"
            "Justification"    = "Add eligible assignment"
            "DirectoryScopeId" = "/"
            "Action"           = "AdminAssign"
            "ScheduleInfo"     = @{
                "StartDateTime" = Get-Date
                "Expiration"    = @{
                    "Type"     = "AfterDuration"
                    "Duration" = "P180D"
                }
            }
        }
        Write-Host "$message Configuring role elibibility for '$pimEligibleGroupName'" -ForegroundColor Cyan
        New-MgRoleManagementDirectoryRoleEligibilityScheduleRequest -BodyParameter $params | out-null
    }

    $output
    Write-Host "$message Configuration Completed." -ForegroundColor Green
    if ($EnableLogs) {
        Stop-Transcript
    }
}
catch {
    Write-Error $_
}
