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
    param (
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
            return [pscustomobject]@{ ID = $User.Id; Type = "User"; DisplayName = $User.DisplayName }
        }
        $Group = Get-MgGroup -Filter "displayName eq '$ObjectName'" -ErrorAction SilentlyContinue
        if ($Group) {
            return [pscustomobject]@{ ID = $Group.Id; Type = "Group"; DisplayName = $Group.DisplayName }
        }
        return $null
    }
    catch {
        Write-Host "[$message]:    " -nonewline
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
        Connect-MgGraph -Scopes "EntitlementManagement.ReadWrite.All", "Directory.Read.All" -NoWelcome
    }

    foreach ($catalog in $json.Catalogs) {
        $fullCatalogName = if ($UsePrefix) { "$prefix - $($catalog.CatalogName)" } else { $catalog.CatalogName }

        Write-Host "[$message]: " -NoNewline
        Write-Host "🚀 Working on catalog: '$fullCatalogName'" -ForegroundColor Cyan

        $catalogObj = Get-MgEntitlementManagementCatalog -Filter "displayName eq '$fullCatalogName'"
        if (-not $catalogObj) {
            Write-Host "[$message]: " -nonewline
            Write-Host "❌ Catalog '$fullCatalogName' not found. Stopping script." -ForegroundColor Red
            break
        }

        foreach ($ap in $catalog.AccessPackages) {
            $apName = $ap.PackageName
            $existingAp = Get-MgEntitlementManagementAccessPackage -Filter "displayName eq '$apName'"
            if (-not $existingAp) {
                $apParams = @{
                    displayName = $apName
                    description = "Access package created for $apName"
                    isHidden    = $ap.Hidden
                    catalog     = @{ id = $catalogObj.Id }
                }
                $newAp = New-MgEntitlementManagementAccessPackage -BodyParameter $apParams
                Write-Host "[$message]:  " -nonewline
                Write-Host "✅ Created Access Package '$apName'" -ForegroundColor Green
                Start-Sleep -Seconds 3
                $newAp = Get-MgEntitlementManagementAccessPackage -Filter "displayName eq '$apName'"
                if (-not $newAp) {
                    Write-Host "[$message]:  " -nonewline
                    Write-Host "❌ Access Package '$apName' could not be confirmed after creation. Skipping." -ForegroundColor Red
                    continue
                }
            }
            else {
                $newAp = $existingAp
                Write-Host "[$message]:  " -nonewline
                Write-Host "ℹ️  Access Package '$apName' already exists. Continuing..." -ForegroundColor Gray
            }

            $catalogResources = Get-MgEntitlementManagementCatalogResource -AccessPackageCatalogId $catalogObj.Id -All

            foreach ($resName in $ap.Resources) {
                $resourceObj = $catalogResources | Where-Object { $_.DisplayName -eq $resName }
                if ($resourceObj) {
                    try {
                        $resourceRoles = Get-MgEntitlementManagementCatalogResourceRole -AccessPackageCatalogId $catalogObj.Id -Filter "resource/id eq '$($resourceObj.Id)' and originSystem eq '$($resourceObj.OriginSystem)'" -ExpandProperty resource
                    }
                    catch {
                        Write-Host "[$message]:    " -nonewline
                        Write-Host "⚠️  Could not retrieve roles for resource '$($resourceObj.DisplayName)'. Skipping." -ForegroundColor Red
                        continue
                    }

                    $memberRole = $resourceRoles | Where-Object { $_.DisplayName -eq "Member" }

                    if ($memberRole) {
                        $params = @{
                            role    = @{
                                displayName  = "Member"
                                originSystem = $resourceObj.OriginSystem
                                originId     = $memberRole.OriginId
                                resource     = @{
                                    id           = $resourceObj.Id
                                    displayName  = $resourceObj.DisplayName
                                    description  = $resourceObj.Description
                                    originId     = $resourceObj.OriginId
                                    originSystem = $resourceObj.OriginSystem
                                }
                            }
                            'scope' = @{
                                displayName  = "Root"
                                description  = "Root Scope"
                                originId     = $catalogObj.Id
                                originSystem = $resourceObj.OriginSystem
                                isRootScope  = $true
                            }
                        }

                        try {
                            New-MgEntitlementManagementAccessPackageResourceRoleScope -AccessPackageId $newAp.Id -BodyParameter $params | Out-Null
                            Write-Host "[$message]:   " -nonewline
                            Write-Host " ➕ Added/confirmed resource '$($resourceObj.DisplayName)' with role 'Member' in access package '$apName'." -ForegroundColor Cyan
                        }
                        catch {
                            Write-Host "[$message]:   " -nonewline
                            Write-Host "⚠️  Failed to add resource '$($resourceObj.DisplayName)' with role 'Member': $_" -ForegroundColor Red
                        }
                    }
                    else {
                        Write-Host "[$message]:  " -nonewline
                        Write-Host "⚠️  No 'Member' role found for resource '$($resourceObj.DisplayName)'." -ForegroundColor red
                    }
                }
                else {
                    Write-Host "[$message]:    " -nonewline
                    Write-Host "⚠️  Resource '$resName' not found in catalog." -ForegroundColor Red
                }
            }

            $existingPolicies = Get-MgEntitlementManagementAssignmentPolicy -Filter "accessPackage/id eq '$($newAp.Id)'"
            foreach ($policy in $ap.Policies) {
                $policyName =  $apName + " - " + $policy.PolicyDisplayName
                $oldPolicy = $existingPolicies | Where-Object { $_.DisplayName -eq $policyName }
                if ($oldPolicy) {
                    Remove-MgEntitlementManagementAssignmentPolicy -AccessPackageAssignmentPolicyId $oldPolicy.Id -Confirm:$false
                    Write-Host "[$message]:    " -nonewline
                    Write-Host "🗑️  Removed existing policy '$($oldPolicy.DisplayName)'" -ForegroundColor Yellow
                }

                $targetObj = Get-ObjectInfo -ObjectName $policy.AllowedTarget
                if (-not $targetObj) {
                    Write-Host "[$message]:    " -nonewline
                    Write-Host "❌ Could not resolve allowed target '$($policy.AllowedTarget)'. Skipping policy."
                    continue
                }

                $expiration = @{}
                if ($policy.ExpirationDate) {
                    if ($policy.ExpirationDays -or $policy.ExpirationHours -or $policy.NeverExpire) {
                        throw "[$message]: Conflicting expiration settings for policy '$policyName'."
                    }
                    $endDateTime = ([datetime]::ParseExact($policy.ExpirationDate, "yyyy-MM-dd", $null).AddHours(22).AddMinutes(59).AddSeconds(59).AddMilliseconds(997)).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                    $expiration = @{ endDateTime = $endDateTime; duration = $null; type = "afterDateTime" }
                } elseif ($policy.ExpirationDays) {
                    $durationInISO = "P$($policy.ExpirationDays)D"
                    $expiration = @{ endDateTime = $null; duration = $durationInISO; type = "afterDuration" }
                } elseif ($policy.ExpirationHours) {
                    $days = [math]::Floor($policy.ExpirationHours / 24)
                    $hours = $policy.ExpirationHours % 24
                    $durationInISO = "P${days}DT${hours}H"
                    $expiration = @{ endDateTime = $null; duration = $durationInISO; type = "afterDuration" }
                } elseif ($policy.NeverExpire) {
                    $expiration = @{ endDateTime = $null; duration = $null; type = "noExpiration" }
                }

                $policyParams = @{
                    accessPackage           = @{ id = $newAp.Id }
                    displayName             = $policyName
                    description             = $policy.PolicyDescription
                    allowedTargetScope      = $policy.TargetScope
                    specificAllowedTargets  = @(
                        if ($targetObj.Type -eq "Group") {
                            @{ '@odata.type' = '#microsoft.graph.groupMembers'; groupId = $targetObj.ID; description = $targetObj.DisplayName }
                        }
                        else {
                            @{ '@odata.type' = '#microsoft.graph.singleUser'; userId = $targetObj.ID; description = $targetObj.DisplayName }
                        }
                    )
                    requestorSettings       = @{
                        enableTargetsToSelfAddAccess           = $policy.EnablePackage
                        enableTargetsToSelfUpdateAccess        = $false
                        enableTargetsToSelfRemoveAccess        = $policy.RequireJustification
                        allowCustomAssignmentSchedule          = $true
                        enableOnBehalfRequestorsToAddAccess    = $false
                        enableOnBehalfRequestorsToUpdateAccess = $false
                        enableOnBehalfRequestorsToRemoveAccess = $false
                        onBehalfRequestors                     = @()
                    }
                    requestApprovalSettings = @{
                        isApprovalRequiredForAdd    = $policy.RequireApproval
                        isApprovalRequiredForUpdate = $false
                        stages                      = @(
                            @{
                                durationBeforeAutomaticDenial   = "P2D"
                                isApproverJustificationRequired = $policy.RequireJustification
                                isEscalationEnabled             = $false
                                durationBeforeEscalation        = "PT0S"
                                primaryApprovers                = @(
                                    if ($targetObj.Type -eq "Group") {
                                        @{ '@odata.type' = '#microsoft.graph.groupMembers'; groupId = $targetObj.ID; description = $targetObj.DisplayName }
                                    }
                                    else {
                                        @{ '@odata.type' = '#microsoft.graph.singleUser'; userId = $targetObj.ID; description = $targetObj.DisplayName }
                                    }
                                )
                                fallbackPrimaryApprovers        = @()
                            }
                        )
                    }
                    expiration              = $expiration
                    reviewSettings          = $null
                }

                try {
                    New-MgEntitlementManagementAssignmentPolicy -BodyParameter $policyParams | Out-Null
                    Write-Host "[$message]:  " -nonewline
                    Write-Host "  ✅ Created policy '$($policy.PolicyDisplayName)' for Access Package '$apName'" -ForegroundColor Green
                }
                catch {
                    Write-Host "[$message]:  " -nonewline
                    Write-Host "❌ Failed to create policy '$($policy.PolicyDisplayName)': $_"
                }
            }
        Write-Host "[$message]:  " -nonewline
        Write-Host "🏁 Finished processing package '$apName'" -ForegroundColor Cyan
        }
    }
    if ($EnableLogs) {
        Stop-Transcript
    }
}
catch {
    Write-Error $_
}