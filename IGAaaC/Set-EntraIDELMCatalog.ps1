[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string] $JsonPath ,
    [Parameter(Mandatory = $false)]
    [switch] $UsePrefix,
    [Parameter(Mandatory = $false)]
    [switch] $EnableLogs
)

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
    $message = $MyInvocation.MyCommand.Name

    $output = @(
        $(New-Object PSObject -Property @{
                JsonPath  = $JsonPath; 
                UsePrefix = $UsePrefix ; 
                Enabled   = $Enabled
            }
        )
    )

    function Get-ObjectID {
        param ([string]$ObjectName)
        $user = Get-MgUser -Filter "userPrincipalName eq '$ObjectName' or displayName eq '$ObjectName'" -ErrorAction SilentlyContinue
        if ($user) { return $user.Id }
        $group = Get-MgGroup -Filter "displayName eq '$ObjectName'" -ErrorAction SilentlyContinue
        if ($group) { return $group.Id }
        Write-Host "[$message]:❌ No user or group found with name: $ObjectName"
        return $null
    }

    function Set-CatalogRole {
        param (
            [string] $ObjectID,
            [string] $RoleID,
            [string] $CatalogId
        )

        $object = Get-MgUser -UserId $ObjectID -ErrorAction SilentlyContinue
        if (-not $object) {
            $object = Get-MgGroup -GroupId $ObjectID -ErrorAction SilentlyContinue
        }
        $objectName = if ($object) { $object.DisplayName } else { $ObjectID }

        $role = Get-MgRoleManagementEntitlementManagementRoleDefinition -UnifiedRoleDefinitionId $RoleID -ErrorAction SilentlyContinue
        $roleName = if ($role) { $role.DisplayName } else { $RoleID }

        $catalog = Get-MgEntitlementManagementCatalog -AccessPackageCatalogId $CatalogId -ErrorAction SilentlyContinue
        $catalogName = if ($catalog) { $catalog.DisplayName } else { $CatalogId }

        $filter = "principalId eq '$ObjectID' and roleDefinitionId eq '$RoleID' and appScopeId eq '/AccessPackageCatalog/$CatalogId'"
        $existing = Get-MgRoleManagementEntitlementManagementRoleAssignment -Filter $filter

        if (-not $existing) {
            $params = @{
                principalId      = $ObjectID
                roleDefinitionId = $RoleID
                appScopeId       = "/AccessPackageCatalog/$CatalogId"
            }
            New-MgRoleManagementEntitlementManagementRoleAssignment -BodyParameter $params | Out-Null
            Write-Host "[$message]:    " -NoNewline
            Write-Host "✅ Assigned role '$roleName' to '$objectName' in catalog '$catalogName'" -ForegroundColor Green
        }
        else {
            Write-Host "[$message]:    " -NoNewline
            Write-Host "ℹ️  Role '$roleName' already assigned to '$objectName' in catalog '$catalogName'. Skipping." -ForegroundColor Gray
        }
    }

    $jsonContent = Get-Content -Raw -Path $JsonPath | ConvertFrom-Json
    $prefix = $jsonContent.Prefix
    $catalogs = $jsonContent.Catalogs

    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes "EntitlementManagement.ReadWrite.All", "Directory.Read.All", "Group.ReadWrite.All", "User.Read.All" -NoWelcome
    }

    foreach ($catalog in $catalogs) {
        if (!$UsePrefix) {
            $CatalogName = "$($catalog.CatalogName)"
        }
        else {
            $CatalogName = "$prefix - $($catalog.CatalogName)"
        }
        Write-Host "[$message]: " -nonewline
        Write-Host "🚀 Starting configuration of Entitlement Management Catalog '$CatalogName'..." -ForegroundColor Cyan

        $CatalogDescription = $catalog.CatalogDescription
        $Published = $catalog.Published
        $ResourceGroups = $catalog.Resources
        $Roles = $catalog.Roles

        $existingCatalog = Get-MgEntitlementManagementCatalog -Filter "displayName eq '$CatalogName'" -ErrorAction Ignore
        if (-not $existingCatalog) {
            Write-Host "[$message]:  " -nonewline
            Write-Host "➕ Creating catalog '$CatalogName'..." -ForegroundColor Green
            $existingCatalog = New-MgEntitlementManagementCatalog -DisplayName $CatalogName -Description $CatalogDescription -IsExternallyVisible:$Published
        }
        else {
            Write-Host "[$message]:  " -nonewline
            Write-Host "ℹ️  Catalog '$CatalogName' already exists. Using existing one." -ForegroundColor Gray
        }
        $catalogId = $existingCatalog.Id

        foreach ($groupName in $ResourceGroups) {
            $group = Get-MgGroup -Filter "displayName eq '$groupName'" -ErrorAction SilentlyContinue
            $wasCreated = $false

            if (-not $group) {
                Write-Host "[$message]:   " -nonewline
                Write-Host "➕ Group '$groupName' not found, creating it..." -ForegroundColor Yellow
                $null = New-MgGroup -DisplayName $groupName -MailEnabled:$false -MailNickname ($groupName -replace '\s', '') -SecurityEnabled:$true -GroupTypes @()
                $wasCreated = $true
            }

            if ($wasCreated) {
                $retryCount = 0
                do {
                    Start-Sleep -Seconds 2
                    $group = Get-MgGroup -Filter "displayName eq '$groupName'" -ErrorAction SilentlyContinue
                    $retryCount++
                } while (-not $group -and $retryCount -lt 10)
            }
            else {
                Write-Host "[$message]:   " -nonewline
                Write-Host "ℹ️  Group '$groupName' already exists." -ForegroundColor Gray
            }

            try {
                $resourceBody = @{
                    requestType = "adminAdd"
                    resource    = @{
                        displayName  = $group.DisplayName
                        originId     = $group.Id
                        originSystem = "AadGroup"
                    }
                    catalog     = @{
                        id = $catalogId
                    }
                }

                New-MgEntitlementManagementResourceRequest -BodyParameter $resourceBody -ErrorAction SilentlyContinue | Out-Null
                Write-Host "[$message]:    " -nonewline
                Write-Host "➕ Adding group '$($group.DisplayName)' to catalog '$CatalogName'" -ForegroundColor Green
            }
            catch {
                if ($_.Exception.Message -match "already exists") {
                    Write-Host "[$message]:    " -nonewline
                    Write-Host "ℹ️ Group '$($group.DisplayName)' is already in catalog '$CatalogName'. Skipping." -ForegroundColor Gray
                }
                else {
                    Write-Warning "[$message]:    " -nonewline
                    Write-Host "⚠️ Failed to add resource '$($group.DisplayName)': $_"
                }
            }
        }

        foreach ($role in $Roles) {
            if (-not $role.RbacConfig) { continue }

            $roleName = $role.RoleName
            $objects = $role.Objects
            $roleId = switch ($roleName) {
                "Owner" { "ae79f266-94d4-4dab-b730-feca7e132178" }
                "Reader" { "44272f93-9762-48e8-af59-1b5351b1d6b3" }
                "PackageManager" { "7f480852-ebdc-47d4-87de-0d8498384a83" }
                "PackageAssignmentManager" { "e2182095-804a-4656-ae11-64734e9b7ae5" }
                default { throw "Unsupported RoleName: $roleName" }
            }

            foreach ($object in $objects) {
                $objectId = Get-ObjectID -ObjectName $object
                if ($objectId) {
                    Write-Host "[$message]:    " -nonewline
                    Write-Host "➕ Assigning role '$roleName' to '$object'" -ForegroundColor Green
                    Set-CatalogRole -ObjectID $objectId -RoleID $roleId -catalogId $catalogId
                }
            }
        }
        Write-Host "[$message]: " -nonewline
        Write-Host "🏁  Finished processing catalog '$CatalogName'" -ForegroundColor Cyan
    }
    if ($EnableLogs) {
        Stop-Transcript
    }
}
catch {
    Write-Error $_
}