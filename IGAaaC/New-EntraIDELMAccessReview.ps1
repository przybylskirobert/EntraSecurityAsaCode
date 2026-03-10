param (
    [string] $AccessReviewName,
    [switch] $ReviewApplication,
    [string] $ApplicationName,
    [ValidateSet("M365", "Group")]
    [string] $ReviewGroupType,
    [string] $GroupName,
    [ValidateSet("GroupOwner", "SelectedUsers", "SelectedGroups", "Managers", "SelfReview")]
    [string] $ReviewerType,
    [string] $ReviewerName,
    [int32] $DurationDays,
    [ValidateSet("OneTime", "Weekly", "Monthly", "Quaterly", "Semi-annually", "Annually")]
    [string] $ReviewReocurence,
    [datetime] $StartDate,
    [switch] $NeverEnd,
    [int32] $EndAfterNumberOfOcurrences,

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
    Write-Host "[$message]: Starting configuration of Access review '$AccessReviewName'..." -ForegroundColor Cyan

    if (-not (Get-Module Microsoft.Graph.Identity.Governance)) {
        Write-Host "[$message]: Importing Microsoft.Graph.Identity.Governance module..."
        Import-Module Microsoft.Graph.Identity.Governance -ErrorAction Stop
    }

    if (-not (Get-MgContext)) {
        Write-Host "[$message]: Connecting to Microsoft Graph..."
        Connect-MgGraph -Scopes "AccessReview.ReadWrite.All" -nowelcome    
    }

    $output = @(
        $(New-Object PSObject -Property @{
                AccessReviewName  = $AccessReviewName; 
                ReviewApplication = $ReviewApplication ; 
                ApplicationName   = $ApplicationName; 
                ReviewGroupType   = $ReviewGroupType; 
                GroupName         = $GroupName; 
                ReviewerType      = $ReviewerType; 
                ReviewerName      = $ReviewerName; 
                DurationDays      = $DurationDays; 
                ReviewReocurence  = $ReviewReocurence; 
                StartDate         = $StartDate; 
                NeverEnd          = $NeverEnd ;          
                EnableLogs        = $EnableLogs
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
            $Application = Get-MgServicePrincipal -Filter "displayName eq '$ObjectName'" -ErrorAction SilentlyContinue
            if ($Application) {
                return [pscustomobject]@{
                    ID          = $Application.Id
                    Type        = "Application"
                    DisplayName = $Application.DisplayName
                }
            }
            Write-Host "No user or group found with the name: $ObjectName"
            return $null
        }
        catch {
            Write-Host "An error occurred: $_"
            return $null
        }
    }

    $params = $null
    $descriptionForAdmins = "to be updated"
    $descriptionForReviewers = "to be updated"


    if ($ReviewGroupType) {
        if (!$GroupName) {
            throw "Missing required parameter 'ApplicationName'"
        }
        Write-Host "[$message]: Configuring Scope for '$GroupName'..." -ForegroundColor Cyan

        $object = Get-ObjectInfo -ObjectName $GroupName
        $reviewScope = @{
            "@odata.type" = "#microsoft.graph.accessReviewQueryScope"
            query         = "/groups/$($Object.id)/transitiveMembers"
            queryType     = "MicrosoftGraph"
        }

        $applyActions = @(
            @{
                '@odata.type' = "#microsoft.graph.removeAccessApplyAction"
            }
        )
        $recommendationInsightSettings = @(
            @{
                '@odata.type'                  = "#microsoft.graph.userLastSignInRecommendationInsightSetting"
                recommendationLookBackDuration = "P30D"
                signInScope                    = "tenant"
            }
        )
    }
    elseif ($ReviewApplication) {
        if (!$ApplicationName) {
            throw "Missing required parameter 'ApplicationName'"
        }
        $object = Get-ObjectInfo -ObjectName $ApplicationName
        Write-Host "[$message]: Configuring Scope for '$ApplicationName'..." -ForegroundColor Cyan

        $principalScopes = @(
            @{
                '@odata.type' = "#microsoft.graph.accessReviewQueryScope"
                query         = '/v1.0/users'
                queryType     = "MicrosoftGraph"
                queryRoot     = $null
            },
            @{
                '@odata.type' = "#microsoft.graph.accessReviewQueryScope"
                query         = './members/microsoft.graph.user'
                queryType     = "MicrosoftGraph"
                queryRoot     = "/v1.0/groups"
            }
        )
        $resourceScopes = @(
            @{
                '@odata.type' = "#microsoft.graph.accessReviewQueryScope"
                query         = "/v1.0/servicePrincipals/$($object.id)"
                queryType     = "MicrosoftGraph"
                queryRoot     = $null
            }
        )
        $reviewScope = @{
            '@odata.type'   = "#microsoft.graph.principalResourceMembershipsScope"
            principalScopes = $principalScopes
            resourceScopes  = $resourceScopes
        }
        $instanceEnumerationScope = $null
        $fallbackReviewers = $null
        $applyActions = @(
            @{
                '@odata.type' = "#microsoft.graph.removeAccessApplyAction"
            }
        )

        $recommendationInsightSettings = @(
            @{
                '@odata.type'                  = "#microsoft.graph.userLastSignInRecommendationInsightSetting"
                recommendationLookBackDuration = "P30D"
                signInScope                    = "application"
            }
        )

    }

    if ($ReviewerType -eq "GroupOwner") {
        Write-Host "[$message]: Configuring reviewers for 'GroupOwner'..." -ForegroundColor Cyan

        $reviewerObject = Get-ObjectInfo -ObjectName $ReviewerName	
        $reviewers = @(
            {
                query 		  = "/v1.0/groups/$($object.ID)/owners"
                queryType     = "MicrosoftGraph"
                queryRoot     = $null
            }
        )
        if ($reviewerObject.Type -eq "User") {
            $fallbackReviewers = @(
                {
                    query         = "/v1.0/users/${reviewerObject.id}"
                    queryType     = "MicrosoftGraph"
                    queryRoot     = $null
                }
            )
        }
        else {
            $fallbackReviewers = @(
                {
                    query         = "/v1.0/groups/${reviewerObject.id}/transitiveMembers/microsoft.graph.user"
                    queryType     = "MicrosoftGraph"
                    queryRoot     = $null
                }
            )
        }
    }
    elseif ($ReviewerType -eq "SelectedUsers") {
        Write-Host "[$message]: Configuring reviewers for 'SelectedUsers'..." -ForegroundColor Cyan

        if (!$ReviewerName) {
            throw "Missing required parameter 'ReviewerName'"
        }
        $reviewerObject = Get-ObjectInfo -ObjectName $ReviewerName
        $reviewers = @(
            @{
                query     = "/v1.0/users/$($reviewerObject.ID)"
                queryType = "MicrosoftGraph"
                queryRoot = "decisions"
            }
        )
        $fallbackReviewers = $null
    }
    elseif ($ReviewerType -eq "SelectedGroups") {
        if (!$ReviewerName) {
            throw "Missing required parameter 'ReviewerName'"
        }
        $reviewerObject = Get-ObjectInfo -ObjectName $ReviewerName
        $reviewers = @(
            @{
                query     = "/v1.0/groups/$($reviewerObject.ID)/transitiveMembers/microsoft.graph.user"
                queryType = "MicrosoftGraph"
                queryRoot = "decisions"
            }
        )
        $fallbackReviewers = $null
    }
    elseif ($ReviewerType -eq "Managers") {
        Write-Host "[$message]: Configuring reviewers for 'Managers'..." -ForegroundColor Cyan

        if (!$ReviewerName) {
            throw "Missing required parameter for fallback 'ReviewerName'"
        }
        $fallbackObject = Get-ObjectID -ObjectID $ReviewerName
        $reviewers = @(
            @{
                query     = "./manager"
                queryType = "MicrosoftGraph"
                queryRoot = "decisions"
            }
        )
        if ($fallbackObject.Type -eq 'User') {
            $query = "/v1.0/users/$($fallbackObject.ID)"
        }
        else {
            $query = "/v1.0/groups/$($fallbackObject.ID)/transitiveMembers/microsoft.graph.user"
        }
        $fallbackReviewers = @(
            @{
                query     = $query
                queryType = "MicrosoftGraph"
                queryRoot = "null"
            }
        )
    }
    elseif ($ReviewerType -eq "SelfReview" -and $null -ne $ReviewGroupType) {
        Write-Host "[$message]: Configuring reviewers for 'SelfReview'..." -ForegroundColor Cyan

        if (!$GroupName) {
            throw "Missing required parameter for self review  'GroupName'"
        }
        $fallbackObject = Get-ObjectID -ObjectID $GroupName
        $reviewers = $null
        $Query = "/v1.0/groups/$($fallbackObject.ID)/owners"
        $fallbackReviewers = @(
            @{
                query     = $query
                queryType = "MicrosoftGraph"
                queryRoot = "null"
            }
        )

    }
    else {
        $fallbackReviewers = $null
        $reviewers = $null
    }

    $endDate = $StartDate.AddDays($DurationDays)
    $formatedEndDate = ($endDate).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $formatedStartDate = ($StartDate).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

    if ($ReviewReocurence -eq "OneTime") {
        Write-Host "[$message]: Configuring reviewers for 'OneTime' use..." -ForegroundColor Cyan

        $recurence = @{
            pattern = $null
            range   = @{
                type                = "endDate"
                numberOfOccurrences = 0
                recurrenceTimeZone  = $null
                startDate           = $formatedStartDate
                endDate             = $formatedEndDate
            }
        }
    }
    elseif ($ReviewReocurence -eq "Weekly") {
        Write-Host "[$message]: Configuring reviewers for 'Weekly' use..." -ForegroundColor Cyan

        $recurence = @{
            pattern = @{
                type           = "Weekly"
                interval       = 1
                month          = 0
                daysOfMoth     = $null
                firstDayOfWeek = "sunday"
                index          = "first"
            }
            range   = @{
                type                = "endDate"
                numberOfOccurrences = 0
                recurrenceTimeZone  = $null
                startDate           = $formatedStartDate
                endDate             = "9999-12-31"
            }
        }
    }
    elseif ($ReviewReocurence -eq "Monthly") {
        Write-Host "[$message]: Configuring reviewers for 'Monthly' use..." -ForegroundColor Cyan

        $recurence = @{
            pattern = @{
                type           = "absoluteMonthly"
                interval       = 1
                month          = 0
                daysOfMoth     = $null
                firstDayOfWeek = "sunday"
                index          = "first"
            }
            range   = @{
                type                = "endDate"
                numberOfOccurrences = 0
                recurrenceTimeZone  = $null
                startDate           = $formatedStartDate
                endDate             = "9999-12-31"
            }
        }
    }
    elseif ($ReviewReocurence -eq "Semi-annually") {
        Write-Host "[$message]: Configuring reviewers for 'Semi-annually' use..." -ForegroundColor Cyan

        $recurence = @{
            pattern = @{
                type           = "absoluteMonthly"
                interval       = 3
                month          = 0
                daysOfMoth     = $null
                firstDayOfWeek = "sunday"
                index          = "first"
            }
            range   = @{
                type                = "endDate"
                numberOfOccurrences = 0
                recurrenceTimeZone  = $null
                startDate           = $formatedStartDate
                endDate             = "9999-12-31"
            }
        }
    }
    elseif ($ReviewReocurence -eq "Annually") {
        Write-Host "[$message]: Configuring reviewers for 'Annually' use..." -ForegroundColor Cyan

        $recurence = @{
            pattern = @{
                type           = "absoluteMonthly"
                interval       = 6
                month          = 0
                daysOfMoth     = $null
                firstDayOfWeek = "sunday"
                index          = "first"
            }
            range   = @{
                type                = "endDate"
                numberOfOccurrences = 0
                recurrenceTimeZone  = $null
                startDate           = $formatedStartDate
                endDate             = "9999-12-31"
            }
        }
    }
    else {
        $recurence = @{
            pattern = @{
                type           = "absoluteMonthly"
                interval       = 12
                month          = 0
                daysOfMoth     = $null
                firstDayOfWeek = "sunday"
                index          = "first"
            }
            range   = @{
                type                = "EndDate"
                numberOfOccurrences = 0
                recurrenceTimeZone  = $null
                startDate           = $formatedStartDate
                endDate             = "9999-12-31"
            }
        }
    }

    $params = @{
        displayName             = $AccessReviewName
        descriptionForAdmins    = "New scheduled access review"
        descriptionForReviewers = "If you have any questions, contact robert.przybylski-admin@identity.formula5.com"
        scope                   = $reviewScope
        reviewers               = $reviewers
        settings                = @{
            mailNotificationsEnabled        = $true
            reminderNotificationsEnabled    = $true
            justificationRequiredOnApproval = $true
            defaultDecisionEnabled          = $true
            defaultDecision                 = "Recommendation"
            instanceDurationInDays          = $DurationDays
            autoApplyDecisionsEnabled       = $true
            recommendationsEnabled          = $true
            recurrence                      = $recurence
        }
    }
    #$params | ConvertTo-Json -Depth 5 | Out-String | Write-Host

    New-MgIdentityGovernanceAccessReviewDefinition -BodyParameter $params | Out-Null
    Write-Host "[$message]: Finished configuring Access review with following parameters." -ForegroundColor Cyan
    $output
    if ($EnableLogs) {
        Stop-Transcript
    }
}
catch {
    Write-Error $_
}