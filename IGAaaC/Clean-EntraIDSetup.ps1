param (
    [Parameter(Mandatory = $false)]
    [string] $Prefix = "LAB",

    [Parameter(Mandatory = $false)]
    [string[]] $CatalogNames = @('T0-Master')
)
$message = $MyInvocation.MyCommand.Name

if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "Directory.ReadWrite.All", "Policy.ReadWrite.ConditionalAccess", "IdentityRiskyUser.ReadWrite.All", "IdentityProvider.ReadWrite.All" -NoWelcome
}

$groupsToRemove = Get-MgGroup -Filter "startsWith(displayName,'$Prefix')" -All
if (($groupsToRemove).count -eq 0) {
    Write-Host "[$message]: " -nonewline
    Write-Host "⚠️  No groups found that starts with prefix '$Prefix'" -ForegroundColor Green
}
else {
    foreach ($group in $groupsToRemove) {
        Write-Host "[$message]:    " -nonewline
        Write-Host "🗑️ Removing group: $($group.DisplayName)"
        Remove-MgGroup -GroupId $group.Id -Confirm:$false
    }
}

foreach ($catalogName in $CatalogNames) {
    $catalog = Get-MgEntitlementManagementCatalog -Filter "displayName eq '$catalogName'"
    if ($catalog) {
        Write-Host "[$message]:    " -nonewline
        Write-Host "🚀 Processing catalog: $($catalog.DisplayName)" -ForegroundColor Cyan
        $accessPackages = Get-MgEntitlementManagementAccessPackage -Filter "catalog/id eq '$($catalog.Id)'" -All
        foreach ($ap in $accessPackages) {
            Write-Host "[$message]:    " -nonewline
            Write-Host "🗑️  Removing access package: $($ap.DisplayName)" -ForegroundColor Yellow
            Remove-MgEntitlementManagementAccessPackage -AccessPackageId $ap.Id -Confirm:$false
        }
        Write-Host "[$message]:    " -nonewline
        Write-Host "🗑️  Removing catalog: $($catalog.DisplayName)" -ForegroundColor Yellow
        Remove-MgEntitlementManagementCatalog -AccessPackageCatalogId $catalog.Id -Confirm:$false
    }
    else {
        Write-Host "[$message]: " -nonewline
        Write-Host "⚠️  Catalog '$catalogName' not found." -ForegroundColor Green
    }
}


$policies = Get-MgIdentityConditionalAccessPolicy -All | Where-Object { $_.DisplayName -like "$Prefix*" }
if (($policies).count -eq 0) {
    Write-Host "[$message]: " -nonewline
    Write-Host "⚠️  No policies found that starts with prefix '$Prefix'" -ForegroundColor Green
}
else {
    foreach ($policy in $policies) {
        Write-Host "[$message]:    " -nonewline
        Write-Host "🗑️ Removing Conditional Access policy: $($policy.DisplayName)"
        Remove-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $policy.Id -Confirm:$false
    }
}

$namedLocations = Get-MgIdentityConditionalAccessNamedLocation -All
$filteredLocations = $namedLocations | Where-Object { $_.DisplayName -like "$Prefix*" }
if (($filteredLocations).count -eq 0) {
    Write-Host "[$message]: " -nonewline
    Write-Host "⚠️  No Named Locations found that starts with prefix '$Prefix'" -ForegroundColor Green
}
else {
    foreach ($location in $filteredLocations) {
        Write-Host "[$message]:    " -nonewline
        Write-Host "🔍 Processing named location: $($location.DisplayName)" -ForegroundColor Cyan

        if ($location.'@odata.type' -eq "#microsoft.graph.ipNamedLocation" -and $location.IsTrusted) {
            Write-Host "[$message]:    " -nonewline
            Write-Host "⚙️  Unchecking 'Trusted location' flag for: $($location.DisplayName)" -ForegroundColor DarkYellow
            $updateParams = @{ IsTrusted = $false }
            Update-MgIdentityConditionalAccessNamedLocation `
                -NamedLocationId $location.Id `
                -BodyParameter $updateParams

            Start-Sleep -Seconds 3
            $location = Get-MgIdentityConditionalAccessNamedLocation -NamedLocationId $location.Id
        }

        if ($location.IsTrusted -eq $false) {
            Write-Host "[$message]:    " -nonewline
            Write-Host "🗑️ Removing named location: $($location.DisplayName)" -ForegroundColor Yellow
            Remove-MgIdentityConditionalAccessNamedLocation -NamedLocationId $location.Id -Confirm:$false
        }
        else {
            Write-Host "[$message]:    " -nonewline
            Write-Host "⚠️ Still marked as trusted. Skipping deletion: $($location.DisplayName)" -ForegroundColor Red
        }
    }
}