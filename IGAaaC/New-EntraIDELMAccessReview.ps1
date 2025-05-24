param (
    [Parameter(Mandatory = $true)]
    [string] $JsonPath,
    [Parameter(Mandatory = $false)]
    [switch] $UsePrefix,
    [Parameter(Mandatory = $false)]
    [switch] $EnableLogs
)

$message = $MyInvocation.MyCommand.Name

function Get-ObjectInfo {
    param ([string]$ObjectName)
    if (-not (Get-Module -Name Microsoft.Graph)) {
        Import-Module Microsoft.Graph -ErrorAction SilentlyContinue
    }
    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes "User.Read.All", "Group.Read.All", "AccessReview.ReadWrite.All" -ErrorAction Stop -NoWelcome
    }
    try {
        $User = Get-MgUser -Filter "userPrincipalName eq '$ObjectName' or displayName eq '$ObjectName'" -ErrorAction SilentlyContinue
        if ($User) {
            return [pscustomobject]@{ ID = $User.Id; Type = "User"; DisplayName = $User.DisplayName }
        }
        $Group = Get-MgGroup -Filter "displayName eq '$ObjectName'" -ErrorAction SilentlyContinue
        if ($Group) {
            return [pscustomobject]@{ ID = $Group.Id; Type = "Group"; DisplayName = $Group.DisplayName }
        }
        return $null
    }
    catch {
        Write-Host "[$message]:    " -NoNewline
        Write-Host "❌ Failed to resolve object '$ObjectName': $_"
        return $null
    }
}

try {
    if ($EnableLogs) {
        $scriptPath = $MyInvocation.MyCommand.Path
        $scriptDir = Join-Path (Split-Path -Path $scriptPath) "Logs"
        if (-not (Test-Path $scriptDir)) { New-Item -ItemType Directory -Path $scriptDir | Out-Null }
        $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($scriptPath)
        $dateTime = (Get-Date).ToString("yyyy_MM-dd HH_mm_ss")
        $logFileName = "$scriptName`_$dateTime.log"
        $logFilePath = Join-Path -Path $scriptDir -ChildPath $logFileName
        Start-Transcript -Path $logFilePath -NoClobber -UseMinimalHeader -Append -Force
    }

    $json = Get-Content -Path $JsonPath -Raw | ConvertFrom-Json
    $prefix = $json.Prefix

    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes "AccessReview.ReadWrite.All" -NoWelcome
    }

    foreach ($catalog in $json.Catalogs) {
        $fullCatalogName = if ($UsePrefix) { "$prefix - $($catalog.CatalogName)" } else { $catalog.CatalogName }

        Write-Host "[$message]: " -NoNewline
        Write-Host "🚀 Starting access review setup for catalog '$fullCatalogName'" -ForegroundColor Cyan

        if (-not $catalog.AccessReviews -or $catalog.AccessReviews.Count -eq 0) {
            Write-Host "[$message]:    " -NoNewline
            Write-Host "ℹ️  No access review configuration found for catalog '$fullCatalogName'. Skipping..." -ForegroundColor Gray
            continue
        }

        foreach ($review in $catalog.AccessReviews) {
            $groupObj = Get-ObjectInfo -ObjectName $review.GroupName
            $reviewerObj = Get-ObjectInfo -ObjectName $review.ReviewerName
            $reviewName = "$($review.GroupName) - $($review.AccessReviewName)"

            if (-not $groupObj -or -not $reviewerObj) {
                Write-Host "[$message]:    " -NoNewline
                Write-Host "❌ Failed to resolve required group or reviewer in accesss review '$reviewName'." -ForegroundColor Red
                continue
            }
            $startDate = [datetime]::ParseExact($review.StartDate, "yyyy-MM-dd", $null)
            $formatedStartDate = $startDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            $formatedEndDate = $startDate.AddDays($review.DurationDays).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

            $existingReview = Get-MgIdentityGovernanceAccessReviewDefinition -Filter "displayName eq '$reviewName'"
            if ($existingReview) {
                Remove-MgIdentityGovernanceAccessReviewDefinition -AccessReviewScheduleDefinitionId $existingReview.Id -Confirm:$false
                Write-Host "[$message]:  " -NoNewline
                Write-Host "🗑️  Removed existing access review '$reviewName'" -ForegroundColor Yellow
            }

            $reviewScope = @{
                "@odata.type" = "#microsoft.graph.accessReviewQueryScope"
                query         = "/groups/$($groupObj.ID)/transitiveMembers"
                queryType     = "MicrosoftGraph"
            }

            $reviewers = @(
                @{
                    query     = "/v1.0/users/$($reviewerObj.ID)"
                    queryType = "MicrosoftGraph"
                    queryRoot = "decisions"
                }
            )

            switch ($review.ReviewReocurence) {
                "OneTime" {
                    $recurrence = @{ pattern = $null; range = @{ type = "endDate"; startDate = $formatedStartDate; endDate = $formatedEndDate } }
                    $type = "OneTime"
                }
                "Weekly" {
                    $recurrence = @{ pattern = @{ type = "weekly"; interval = 1; daysOfWeek = @("sunday") }; range = @{ type = "endDate"; startDate = $formatedStartDate; endDate = "9999-12-31" } }
                    $type = "Weekly"
                }
                "Monthly" {
                    $recurrence = @{ pattern = @{ type = "absoluteMonthly"; interval = 1; dayOfMonth = 1 }; range = @{ type = "endDate"; startDate = $formatedStartDate; endDate = "9999-12-31" } }
                    $type = "Monthly"
                }
                "Quaterly" {
                    $recurrence = @{ pattern = @{ type = "absoluteMonthly"; interval = 3; dayOfMonth = 1 }; range = @{ type = "endDate"; startDate = $formatedStartDate; endDate = "9999-12-31" } }
                    $type = "Quaterly"
                }
                "Semi-annually" {
                    $recurrence = @{ pattern = @{ type = "absoluteMonthly"; interval = 6; dayOfMonth = 1 }; range = @{ type = "endDate"; startDate = $formatedStartDate; endDate = "9999-12-31" } }
                    $type = "Semi-annually"
                }
                "Annually" {
                    $recurrence = @{ pattern = @{ type = "absoluteMonthly"; interval = 12; dayOfMonth = 1 }; range = @{ type = "endDate"; startDate = $formatedStartDate; endDate = "9999-12-31" } }
                    $type = "Annually"
                }
                default {
                    $recurrence = @{ pattern = $null; range = @{ type = "endDate"; startDate = $formatedStartDate; endDate = $formatedEndDate } }
                }
            }

            $params = @{
                displayName             = $reviewName
                descriptionForAdmins    = "Access review for group $($groupObj.DisplayName)"
                descriptionForReviewers = "Please confirm access for members of $($groupObj.DisplayName)."
                scope                   = $reviewScope
                reviewers               = $reviewers
                settings                = @{
                    mailNotificationsEnabled        = $true
                    reminderNotificationsEnabled    = $true
                    justificationRequiredOnApproval = $true
                    defaultDecisionEnabled          = $true
                    defaultDecision                 = "Recommendation"
                    instanceDurationInDays          = $review.DurationDays
                    autoApplyDecisionsEnabled       = $true
                    recommendationsEnabled          = $true
                    recurrence                      = $recurrence
                }
            }

            try {
                New-MgIdentityGovernanceAccessReviewDefinition -BodyParameter $params | Out-Null
                Write-Host "[$message]:    " -NoNewline
                Write-Host "✅ Created '$type' access review '$reviewName'" -ForegroundColor Green
            }
            catch {
                Write-Host "[$message]:    " -NoNewline
                Write-Host "❌ Failed to create '$type' access review '$reviewName': $_" -ForegroundColor Red
            }
        }

        Write-Host "[$message]: " -nonewline
        Write-Host "🏁 Finished processing Access Reviews for catalog '$fullCatalogName'" -ForegroundColor Cyan
    }

    if ($EnableLogs) {
        Stop-Transcript
    }
}
catch {
    Write-Error $_
}
