[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]    $CatalogName,

    [Parameter(Mandatory = $false)]
    [switch]    $ResourceConfig,

    [Parameter(Mandatory = $false)]        
    [PSObject[]]  $Resources,

    [Parameter(Mandatory = $false)]
    [switch]    $RbacConfig,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Owner", "Reader", "PackageManager", "PackageAssignmentManager")]
    [string] $RoleName,

    [Parameter(Mandatory = $false)]
    [string[]]  $Objects,

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
    $output = @(
        $(New-Object PSObject -Property @{
                CatalogName                   = $CatalogName; 
                ResourceConfig                = $ResourceConfig ; 
                Resources                     = $Resources; 
                RbacConfig                    = $RbacConfig; 
                OwnerRoles                    = $OwnerRoles;
                ReaderRoles                   = $ReaderRoles; 
                PackageManagerRoles           = $PackageManagerRoles; 
                PackageAssignmentManagerRoles = $PackageAssignmentManagerRoles;
                Enabled                       = $Enabled
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
            $ServicePrincipal = Get-MgServicePrincipal -Filter "displayName eq '$ObjectName'" -ErrorAction SilentlyContinue
            if ($ServicePrincipal) {
                return [pscustomobject]@{
                    ID          = $ServicePrincipal.Id
                    Type        = "ServicePrincipal"
                    DisplayName = $ServicePrincipal.DisplayName
                }
            }
            $Application = Get-MgApplication -Filter "displayName eq '$ObjectName'" -ErrorAction SilentlyContinue
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

    $message = $MyInvocation.MyCommand.Name
    Write-Host "[$message]: Starting configuration of Entitlement Management Catalog '$CatalogName'..." -ForegroundColor Cyan

    if (-not (Get-Module Microsoft.Graph.Identity.Governance)) {
        Write-Host "[$message]: Importing Microsoft.Graph.Identity.Governance module..."
        Import-Module Microsoft.Graph.Identity.Governance -ErrorAction Stop
    }

    if (-not (Get-MgContext)) {
        Write-Host "[$message]: Connecting to Microsoft Graph..."
        Connect-MgGraph -Scopes "EntitlementManagement.ReadWrite.All", "Directory.Read.All" -ErrorAction Stop -NoWelcome
    }
    
    try {
        $existingCatalog = Get-MgEntitlementManagementCatalog -Filter "displayName eq '$CatalogName'" -ErrorAction Ignore
        $catalogId = $existingCatalog.Id
    }
    catch {
        throw "[$message]: Catalog '$CatalogName' not found."

    }
    $organization = Get-MgOrganization
    $fullTenantName = ($organization.VerifiedDomains | Where-Object { $_.IsInitial -eq $true } | Select-Object -ExpandProperty Name)
    $dotIndex = $fullTenantName.IndexOf(".")
    $tenantName = $fullTenantName.Substring(0, $dotIndex)

    if ($ResourceConfig) {
        if (-not $Resources) {
            Write-Warning "[$message]: ResourceConfig requires the -Resources parameter with valid resource definitions."
        }
        else {
            Write-Host "[$message]: Configuring resources for catalog '$CatalogName'..." -ForegroundColor Cyan
            
            foreach ($resource in $Resources) {
                $type = $resource.Type
                $resourceName = $resource.Name
                $id = (Get-ObjectInfo -ObjectName $resource.Name).id
                $resourceAction = $resource.action
                if ($id -like "https://$tenantname.sharepoint.com/*") {
                    $originSystem = "SharePointOnline"
                    $id = $id
                }
                else {
                    $directoryObject = Get-MgDirectoryObject -DirectoryObjectId  $id 
                    $objectType = $directoryObject.AdditionalProperties.'@odata.type'            
                    switch ($objectType) {
                        '#microsoft.graph.group' {
                            $objectName = Get-MgGroup -GroupId $id
                            $originSystem = "AadGroup"
                        }
                        '#microsoft.graph.servicePrincipal' {
                            $objectName = Get-MgServicePrincipal -ServicePrincipalId $id
                            $originSystem = "AadApplication"
                        }
                        '#microsoft.graph.application' {
                            $objectName = Get-MgApplication -ApplicationId $id
                            $originSystem = "AadApplication"
                        }
                        default {
                            Write-Warning "Unhandled object type: $objectType"
                        }
                    }
                }
                $displayname = $objectname.displayname
                if ($resourceAction -eq 'Add') {
                    $resourceBody = @{
                        requestType = "adminAdd"
                        resource    = @{
                            displayName  = $displayname
                            originId     = $id
                            originSystem = $originSystem
                        }
                        catalog     = @{
                            id = $catalogId
                        }
                    }
                }
                try {
                    New-MgEntitlementManagementResourceRequest -BodyParameter $resourceBody | out-null
                    Write-Host "[$message]: Successfully added resource '$($objectName.DisplayName)' (Type: '$type', ID: '$id') to the catalog." -ForegroundColor Green
                }
                catch {
                    Write-Error "[$message]: Failed to add resource '$($objectName.DisplayName)' (Type: '$type', ID: '$id'): $_"
                }            
            }
        }
    }
    if ($RbacConfig) {
        Write-Host "[$message]: Configuring RBAC roles for catalog '$CatalogName'..." -ForegroundColor Cyan

        if (-not $CatalogId) {
            Write-Error "[$message]: Catalog ID is required to configure RBAC roles."
            return
        }

        function Set-CatalogRole {
            param (
                [string] $ObjectID,
                [string] $RoleID,
                [string] $catalogId
            )
        
            try {
                $filter = "principalId eq '$ObjectID' and roleDefinitionId eq '$RoleID' and appScopeId eq '/AccessPackageCatalog/$catalogId'"
                $existingAssignments = Get-MgRoleManagementEntitlementManagementRoleAssignment -Filter $filter
        
                if ($existingAssignments) {
                    Write-Host "An active role assignment already exists for principalId '$ObjectID' with role '$RoleID' in catalog '$catalogId'. Skipping assignment."
                }
                else {
                    $params = @{
                        principalId      = $ObjectID
                        roleDefinitionId = $RoleID
                        appScopeId       = "/AccessPackageCatalog/$catalogId"
                    }
                    New-MgRoleManagementEntitlementManagementRoleAssignment -BodyParameter $params
                    Write-Host "Role assignment created for principalId '$ObjectID' with role '$RoleID' in catalog '$catalogId'."
                }
            }
            catch {
                Write-Error "Failed to assign '$RoleID' role to subject ID '$ObjectID': $_"
            }
        }

        function Get-ObjectID {
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
                    return $User.Id
                }
                $Group = Get-MgGroup -Filter "displayName eq '$ObjectName'" -ErrorAction SilentlyContinue
                if ($Group) {
                    return $Group.Id
                }
                Write-Host "No user or group found with the name: $ObjectName"
                return $null
            }
            catch {
                Write-Host "An error occurred: $_"
                return $null
            }
        }
        
        if ($RoleName -eq "Owner") {
            foreach ($object in $Objects) {
                $id = "ae79f266-94d4-4dab-b730-feca7e132178"
                $objectID = Get-ObjectID -ObjectName $object 
                Write-Host "[$message]: Assigning 'Owner' role to: '$object'" -ForegroundColor Green
                Set-CatalogRole  -ObjectID $objectID -RoleID $id -catalogId $catalogId | out-null
            }
        }
        if ($RoleName -eq "Reader") {
            foreach ($object in $Objects) {
                $id = "44272f93-9762-48e8-af59-1b5351b1d6b3"
                $objectID = Get-ObjectID -ObjectName $object 
                Write-Host "[$message]: Assigning 'Reader' role to: '$object'" -ForegroundColor Green
                Set-CatalogRole  -ObjectID $objectID -RoleID $id -catalogId $catalogId | out-null
            }
        }
        if ($RoleName -eq "PackageManager") {
            foreach ($object in $Objects) {
                $id = "7f480852-ebdc-47d4-87de-0d8498384a83"
                $objectID = Get-ObjectID -ObjectName $object
                Write-Host "[$message]: Assigning 'Package Manager' role to: '$object'" -ForegroundColor Green
                Set-CatalogRole  -ObjectID $objectID -RoleID $id -catalogId $catalogId | out-null
            }
        }
        if ($RoleName -eq "PackageAssignmentManager") {
            foreach ($object in $Objects) {
                $id = "e2182095-804a-4656-ae11-64734e9b7ae5"
                $objectID = Get-ObjectID -ObjectName $object 
                Write-Host "[$message]: Assigning 'Package Assignment Manager' role to: '$object'" -ForegroundColor Green
                Set-CatalogRole  -ObjectID $objectID -RoleID $id -catalogId $catalogId | out-null
            }
        }
    }

    Write-Host "[$message]: Finished configuring Entitlement Management Catalog '$CatalogName'." -ForegroundColor Cyan
    $output

    if ($EnableLogs) {
        Stop-Transcript
    }
}
catch {
    Write-Error $_
}