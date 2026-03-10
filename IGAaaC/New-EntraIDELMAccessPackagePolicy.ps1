
param (
    [Parameter(Mandatory = $true)]
    [string] $AccessPackageName,

    [Parameter(Mandatory = $true)]
    [string] $PolicyDisplayName, 

    [Parameter(Mandatory = $true)]
    [string] $PolicyDescription,
    [Parameter(Mandatory = $true)]
    [switch] $EnablePackage,

    [Parameter(Mandatory = $true)]
    [ValidateSet("allDirectoryUsers", 'allMemberUsers', "specificDirectoryUsers", 'notSpecified')]
    [string] $TargetScope,
    [string] $AllowedTarget,

    [switch] $RequireApproval,
    [switch] $RequireJustification,
    [switch] $ManagerApproval,
    [string] $ApproverDisplayName,

    [string] $ExpirationDate,
    [int32] $ExpirationDays,
    [int32] $ExpirationHours,
    [switch] $NeverExpire,

    [switch] $EnableAccessReview,

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

    $message = "[$($MyInvocation.MyCommand.Name)] :"
    Write-Host "$message  Starting configuration of Access Package Policy '$AccessPackageName'..." -ForegroundColor Cyan

    if (-not (Get-Module Microsoft.Graph.Identity.Governance)) {
        Write-Host "$message  Importing Microsoft.Graph.Identity.Governance module..."
        Import-Module Microsoft.Graph.Identity.Governance -ErrorAction Stop
    }

    if (-not (Get-MgContext)) {
        Write-Host "$message  Connecting to Microsoft Graph..."
        Connect-MgGraph -Scopes "EntitlementManagement.ReadWrite.All" -nowelcome    
    }

    $output = @(
        $(New-Object PSObject -Property @{
                AccessPackageName    = $AccessPackageName; 
                PolicyDisplayName    = $PolicyDisplayName ; 
                PolicyDescription    = $PolicyDescription; 
                EnablePackage        = $EnablePackage; 
                TargetScope          = $TargetScope; 
                AllowedTarget        = $AllowedTarget; 
                OnBehalfRequestors   = $OnBehalfRequestors;
                RequireApproval      = $RequireApproval; 
                RequireJustification = $RequireJustification; 
                ManagerApproval      = $ManagerApproval; 
                ApproverDisplayName  = $ApproverDisplayName; 
                ExpirationDate       = $ExpirationDate; 
                ExpirationDays       = $ExpirationDays ;          
                NeverExpire          = $NeverExpire;
                EnableAccessReview   = $EnableAccessReview
            }
        )
    )

    function Get-ObjectInfo {
        param (
            [Parameter(Mandatory = $true)]
            [string]$ObjectName
        )
        if (-not (Get-Module -Name Microsoft.Graph)) {
            Import-Module Microsoft.Graph -ErrorAction SilentlyContinue
        }
        if (-not (Get-MgContext)) {
            Connect-MgGraph -Scopes "User.Read.All", "Group.Read.All" -ErrorAction Stop -NoWelcome
        }
        try {
            $User = Get-MgUser -Filter "userPrincipalName eq '$ObjectName' or displayName eq '$ObjectName'" -ErrorAction SilentlyContinue
            if ($User) {
                return [pscustomobject]@{
                    ID          = $User.Id
                    Type        = "User"
                    DisplayName = $User.DisplayName
                }
            }
            $Group = Get-MgGroup -Filter "displayName eq '$ObjectName'" -ErrorAction SilentlyContinue
            if ($Group) {
                return [pscustomobject]@{
                    ID          = $Group.Id
                    Type        = "Group"
                    DisplayName = $Group.DisplayName
                }
            }
            Write-Host "$message No user or group found with the name: $ObjectName"
            return $null
        }
        catch {
            Write-Host "An error occurred: $_"
            return $null
        }
    }

    $accessPackage = Get-MgEntitlementManagementAccessPackage -Filter "displayName eq '$AccessPackageName'"
    if ($EnablePackage) {
        $enabled = $true
    }
    else {
        $enabled = $false
    }
    if ($RequireJustification) {
        $justification = $true
    }
    else {
        $justification = $false
    }

    if ($TargetScope -eq "specificDirectoryUsers") {
        if (-not $AllowedTarget ) {
            throw "Missing required parameter 'AllowedTarget'"
        }
        $object = Get-ObjectInfo -ObjectName $AllowedTarget
        if ($object.Type -eq "user") {
            $specificAllowedTargets = @(
                @{
                    '@odata.type' = '#microsoft.graph.singleUser'
                    userId        = $object.ID
                    description   = $object.DisplayName
                }
            )
        }
        else {
            $specificAllowedTargets = @(
                @{
                    '@odata.type' = '#microsoft.graph.groupMembers'
                    groupId       = $object.ID
                    description   = $object.DisplayName
                }
            )
        }
    }
    else {
        $specificAllowedTargets = $null
    }

    if ($RequireApproval) {
        if (!$ApproverDisplayName) {
            throw "$message Missing parameter declaration for 'ApproverDisplayName'"
        }
        $falbackApprover = Get-ObjectInfo -ObjectName $ApproverDisplayName
        if ($falbackApprover.Type -eq 'user') {
            if ($ManagerApproval) {
                $policySetup = @{
                    accessPackage           = @{
                        id = $accessPackage.id
                    }
                    displayName             = $PolicyDisplayName
                    description             = $PolicyDescription
                    allowedTargetScope      = $TargetScope
                    specificAllowedTargets  = $specificAllowedTargets
                    requestorSettings       = @{
                        enableTargetsToSelfAddAccess           = $enabled
                        enableTargetsToSelfUpdateAccess        = $false
                        enableTargetsToSelfRemoveAccess        = $justification
                        allowCustomAssignmentSchedule          = $true
                        enableOnBehalfRequestorsToAddAccess    = $true
                        enableOnBehalfRequestorsToUpdateAccess = $false
                        enableOnBehalfRequestorsToRemoveAccess = $true
                        onBehalfRequestors                     = @(
                            @{
                                "@odata.type" = "#microsoft.graph.targetManager"
                                managerLevel = 1
                            }     
                        )       
                    }
                    requestApprovalSettings = @{
                        isApprovalRequiredForAdd    = $true
                        isApprovalRequiredForUpdate = $false
                        stages                      = @(
                            @{
                                durationBeforeAutomaticDenial   = "P2D"
                                isApproverJustificationRequired = $justification
                                isEscalationEnabled             = $false
                                durationBeforeEscalation        = "PT0S"
                                primaryApprovers                = @(
                                    @{
                                        "@odata.type" = "#microsoft.graph.requestorManager"
                                        managerLevel  = 1
                                    }
                                )
                                fallbackPrimaryApprovers        = @(
                                    @{
                                        "@odata.type" = "#microsoft.graph.singleUser"
                                        userId        = $falbackApprover.ID
                                        description   = $falbackApprover.DisplayName
                                    }
                                )
                                escalationApprovers             = @(
                                )
                                fallbackEscalationApprovers     = @(
                                )
                            }
                        )
                    }
                    reviewSettings          = $null
                }
            }
            else {
                $policySetup = @{
                    accessPackage           = @{
                        id = $accessPackage.id
                    }
                    displayName             = $PolicyDisplayName
                    description             = $PolicyDescription
                    allowedTargetScope      = $TargetScope
                    specificAllowedTargets  = $specificAllowedTargets
                    requestorSettings       = @{
                        enableTargetsToSelfAddAccess           = $enabled
                        enableTargetsToSelfUpdateAccess        = $false
                        enableTargetsToSelfRemoveAccess        = $justification
                        allowCustomAssignmentSchedule          = $true
                        enableOnBehalfRequestorsToAddAccess    = $true
                        enableOnBehalfRequestorsToUpdateAccess = $false
                        enableOnBehalfRequestorsToRemoveAccess = $true
                        onBehalfRequestors                     = @(
                            @{
                                "@odata.type" = "#microsoft.graph.targetManager"
                                managerLevel = 1
                            }     
                        )              
                    }
                    requestApprovalSettings = @{
                        isApprovalRequiredForAdd    = $true
                        isApprovalRequiredForUpdate = $false
                        stages                      = @(
                            @{
                                durationBeforeAutomaticDenial   = "P2D"
                                isApproverJustificationRequired = $justification
                                isEscalationEnabled             = $false
                                durationBeforeEscalation        = "PT0S"
                                primaryApprovers                = @(
                                    @{
                                        "@odata.type" = "#microsoft.graph.singleUser"
                                        userId        = $falbackApprover.ID
                                        description   = $falbackApprover.DisplayName
                                    }
                                )
                                escalationApprovers             = @(
                                )
                                fallbackEscalationApprovers     = @(
                                )
                            }
                        )
                    }
                    reviewSettings          = $null
                }
            }
        }
        else {
            if ($ManagerApproval) {
                $policySetup = @{
                    accessPackage           = @{
                        id = $accessPackage.id
                    }
                    displayName             = $PolicyDisplayName
                    description             = $PolicyDescription
                    allowedTargetScope      = $TargetScope
                    specificAllowedTargets  = $specificAllowedTargets
                    requestorSettings       = @{
                        enableTargetsToSelfAddAccess           = $enabled
                        enableTargetsToSelfUpdateAccess        = $false
                        enableTargetsToSelfRemoveAccess        = $justification
                        allowCustomAssignmentSchedule          = $true
                        enableOnBehalfRequestorsToAddAccess    = $true
                        enableOnBehalfRequestorsToUpdateAccess = $false
                        enableOnBehalfRequestorsToRemoveAccess = $true
                        onBehalfRequestors                     = @(
                            @{
                                "@odata.type" = "#microsoft.graph.targetManager"
                                managerLevel = 1
                            }     
                        )                       
                    }
                    requestApprovalSettings = @{
                        isApprovalRequiredForAdd    = $true
                        isApprovalRequiredForUpdate = $false
                        stages                      = @(
                            @{
                                durationBeforeAutomaticDenial   = "P2D"
                                isApproverJustificationRequired = $justification
                                isEscalationEnabled             = $false
                                durationBeforeEscalation        = "PT0S"
                                primaryApprovers                = @(
                                    @{
                                        "@odata.type" = "#microsoft.graph.requestorManager"
                                        managerLevel  = 1
                                    }
                                )
                                fallbackPrimaryApprovers        = @(
                                    @{
                                        "@odata.type" = "#microsoft.graph.groupMembers"
                                        groupID       = $falbackApprover.ID
                                        description   = $falbackApprover.DisplayName
                                    }
                                )
                                escalationApprovers             = @(
                                )
                                fallbackEscalationApprovers     = @(
                                )
                            }
                        )
                    }
                    reviewSettings          = $null
                }
            }
            else {
                $policySetup = @{
                    accessPackage           = @{
                        id = $accessPackage.id
                    }
                    displayName             = $PolicyDisplayName
                    description             = $PolicyDescription
                    allowedTargetScope      = $TargetScope
                    specificAllowedTargets  = $specificAllowedTargets
                    requestorSettings       = @{
                        enableTargetsToSelfAddAccess           = $enabled
                        enableTargetsToSelfUpdateAccess        = $false
                        enableTargetsToSelfRemoveAccess        = $justification
                        allowCustomAssignmentSchedule          = $true
                        enableOnBehalfRequestorsToAddAccess    = $true
                        enableOnBehalfRequestorsToUpdateAccess = $false
                        enableOnBehalfRequestorsToRemoveAccess = $true
                        onBehalfRequestors                     = @(
                            @{
                                "@odata.type" = "#microsoft.graph.targetManager"
                                managerLevel = 1
                            }     
                        )                     
                    }
                    requestApprovalSettings = @{
                        isApprovalRequiredForAdd    = $true
                        isApprovalRequiredForUpdate = $false
                        stages                      = @(
                            @{
                                durationBeforeAutomaticDenial   = "P2D"
                                isApproverJustificationRequired = $justification
                                isEscalationEnabled             = $false
                                durationBeforeEscalation        = "PT0S"
                                primaryApprovers                = @(
                                    @{
                                        "@odata.type" = "#microsoft.graph.groupMembers"
                                        groupID       = $falbackApprover.ID
                                        description   = $falbackApprover.DisplayName
                                    }
                                )
                                escalationApprovers             = @(
                                )
                                fallbackEscalationApprovers     = @(
                                )
                            }
                        )
                    }
                    reviewSettings          = $null
                }

            }
        }
    }
    else {
        $policySetup = @{
            accessPackage           = @{
                id = $accessPackage.id
            }
            displayName             = $PolicyDisplayName
            description             = $PolicyDescription
            allowedTargetScope      = $TargetScope
            specificAllowedTargets  = $specificAllowedTargets
            requestorSettings       = @{
                enableTargetsToSelfAddAccess           = $enabled
                enableTargetsToSelfUpdateAccess        = $false
                enableTargetsToSelfRemoveAccess        = $justification
                allowCustomAssignmentSchedule          = $true
                enableOnBehalfRequestorsToAddAccess    = $true
                enableOnBehalfRequestorsToUpdateAccess = $false
                enableOnBehalfRequestorsToRemoveAccess = $true
                onBehalfRequestors                     = @(
                    @{
                        "@odata.type" = "#microsoft.graph.targetManager"
                        "managerLevel" = 1
                    }   
                )        
            }
            requestApprovalSettings = @{
                isApprovalRequiredForAdd    = $false
                isApprovalRequiredForUpdate = $false
                stages                      = @(
                )
            }
            reviewSettings          = @()
        }
    }
    
    if ($ExpirationDate -ne "") {
        if ($ExpirationDays -or $ExpirationHours -or $NeverExpire) {
            throw "$message Those parameters 'ExpirationDays' 'ExpirationHours' 'NeverExpire' are conficling  with ExpirationDate. Select only one"
        }
        $endDateTime = ([datetime]::ParseExact($ExpireAfterDays, "yyyy-MM-dd", $null).AddHours(22).AddMinutes(59).AddSeconds(59).AddMilliseconds(997)).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        $description = "Policy configured to use expiration date set to '$ExpireAfterDays'"
        $policysetup.description = $description
        $policySetup.expiration = @{
            endDateTime = $endDateTime
            duration    = $null 
            type        = "afterDateTime"
        }
    }
    if ($ExpirationDays -ne "") {
        if ($ExpirationDate -or $ExpirationHours -or $NeverExpire) {
            throw "$message Those parameters 'ExpirationDate' 'ExpirationHours' 'NeverExpire' are conficling  with ExpirationDays. Select only one"
        }
        $durationInISO = "P${ExpirationDays}D"
        $description = "Policy configured to use expiration after '$ExpirationDays' days"
        $policysetup.description = $description
        $policySetup.expiration = @{
            endDateTime = $null
            duration    = $durationInISO 
            type        = "afterDuration"
        }
    }
    if ($ExpirationHours -ne "") {
        if ($ExpirationDate -or $ExpirationDays -or $NeverExpire) {
            throw "$message Those parameters 'ExpirationDate' 'ExpirationDays' 'NeverExpire' are conficling  with ExpirationHours. Select only one"
        }
        $days = [math]::Floor($ExpirationHours / 24)
        $hours = $ExpirationHours % 24 
        $durationInISO = "P${days}DT${hours}H"
        $description = "Policy configured to use expiration after '$ExpirationHours' hours"
        $policysetup.description = $description
        $policySetup.expiration = @{
            endDateTime = $null
            duration    = $durationInISO 
            type        = "afterDuration"
        }
    }
    if ($NeverExpire -ne $false) {
        if ($ExpirationDate -or $ExpirationDays -or $ExpirationHours) {
            throw "$message Those parameters 'ExpirationDate' 'ExpirationDays' 'ExpirationHours' are conficling  with NeverExpire. Select only one"
        }
        $description = "Policy configured not to expire"
        $policysetup.description = $description
        $policySetup.expiration = @{
            endDateTime = $null
            duration    = $null
            type        = "noExpiration"
        }
    }


    if ($EnableAccessReview) {
        $date = (Get-Date).AddHours(3).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        $falbackApprover = Get-ObjectInfo -ObjectName $ApproverDisplayName
        if ($falbackApprover.Type -eq "user") {
            if ($ManagerApproval) {
                $policySetup.reviewSettings = @{
                    isEnabled                       = $true
                    expirationBehavior              = "keepAccess"
                    isRecommendationEnabled         = $true
                    isReviewerJustificationRequired = $true
                    isSelfReview                    = $false
                    schedule                        = @{
                        startDateTime = $date
                        expiration    = @{
                            duration = "P14D"
                            type     = "afterDuration"
                        }
                        recurrence    = @{
                            pattern = @{
                                type       = "absoluteMonthly"
                                interval   = 1
                                month      = 0
                                dayOfMonth = 0
                                daysOfWeek = @(
                                )
                            }
                            range   = @{
                                type                = "noEnd"
                                numberOfOccurrences = 0
                            }
                        }
                    }
                    primaryReviewers                = @(
                        @{
                            "@odata.type" = "#microsoft.graph.targetManager"
                            managerLevel  = 1
                        }
                    )
                    fallbackReviewers               = @(
                        @{
                            "@odata.type" = "#microsoft.graph.singleUser"
                            userId        = $falbackApprover.ID
                        }
                    )
                }
            }
            else {
                $policySetup.reviewSettings = @{
                    isEnabled                       = $true
                    expirationBehavior              = "keepAccess"
                    isRecommendationEnabled         = $true
                    isReviewerJustificationRequired = $true
                    isSelfReview                    = $false
                    schedule                        = @{
                        startDateTime = $date
                        expiration    = @{
                            duration = "P14D"
                            type     = "afterDuration"
                        }
                        recurrence    = @{
                            pattern = @{
                                type       = "absoluteMonthly"
                                interval   = 1
                                month      = 0
                                dayOfMonth = 0
                                daysOfWeek = @(
                                )
                            }
                            range   = @{
                                type                = "noEnd"
                                numberOfOccurrences = 0
                            }
                        }
                    }
                    primaryReviewers                = @(
                        @{
                            "@odata.type" = "#microsoft.graph.singleUser"
                            userId        = $falbackApprover.ID
                        }
                    )
                    fallbackReviewers               = @(
                    )
                }
            }
        }
        else {
            if ($ManagerApproval) {
                $policySetup.reviewSettings = @{
                    isEnabled                       = $true
                    expirationBehavior              = "keepAccess"
                    isRecommendationEnabled         = $true
                    isReviewerJustificationRequired = $true
                    isSelfReview                    = $false
                    schedule                        = @{
                        startDateTime = $date
                        expiration    = @{
                            duration = "P14D"
                            type     = "afterDuration"
                        }
                        recurrence    = @{
                            pattern = @{
                                type       = "absoluteMonthly"
                                interval   = 1
                                month      = 0
                                dayOfMonth = 0
                                daysOfWeek = @(
                                )
                            }
                            range   = @{
                                type                = "noEnd"
                                numberOfOccurrences = 0
                            }
                        }
                    }
                    primaryReviewers                = @(
                        @{
                            "@odata.type" = "#microsoft.graph.targetManager"
                            managerLevel  = 1
                        }
                    )
                    fallbackReviewers               = @(
                        @{
                            "@odata.type" = "#microsoft.graph.singleUser"
                            userId        = $falbackApprover.ID
                        }
                    )
                }
            }
            else {
                $policySetup.reviewSettings = @{
                    isEnabled                       = $true
                    expirationBehavior              = "keepAccess"
                    isRecommendationEnabled         = $true
                    isReviewerJustificationRequired = $true
                    isSelfReview                    = $false
                    schedule                        = @{
                        startDateTime = $date
                        expiration    = @{
                            duration = "P14D"
                            type     = "afterDuration"
                        }
                        recurrence    = @{
                            pattern = @{
                                type       = "absoluteMonthly"
                                interval   = 1
                                month      = 0
                                dayOfMonth = 0
                                daysOfWeek = @(
                                )
                            }
                            range   = @{
                                type                = "noEnd"
                                numberOfOccurrences = 0
                            }
                        }
                    }
                    primaryReviewers                = @(
                        @{
                            "@odata.type" = "#microsoft.graph.singleUser"
                            userId        = $falbackApprover.ID
                        }
                    )
                    fallbackReviewers               = @(

                    )
                }
            }
        }
    }

    $assignmentPolicy = New-MgEntitlementManagementAssignmentPolicy -BodyParameter $policySetup
    Write-Host "$message Policy has been created as per detils below:" -ForegroundColor Green
    $output
    if ($EnableLogs) {
        Stop-Transcript
    }
}
catch {
    Write-Error $_
}