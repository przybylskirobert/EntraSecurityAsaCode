param(
    [Parameter(Mandatory = $true)]
    [string] $CatalogName,
    [Parameter(Mandatory = $true)]
    [string] $PackageName,
    [Parameter(Mandatory = $false)]
    [switch]$Hidden,
    [Parameter(Mandatory = $false)]
    [psobject]$CatalogResources,
    [Parameter(Mandatory = $false)]
    [psobject]$PolicySetup,
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
                CatalogName      = $CatalogName; 
                PackageName      = $PackageName ; 
                Hidden           = $Hidden; 
                CatalogResources = $CatalogResources; 
                PolicySetup      = $PolicySetup; 
                EnableLogs       = $EnableLogs
            }
        )
    )


    $message = "[$($MyInvocation.MyCommand.Name)]: "

    if (-not (Get-Module Microsoft.Graph.Identity.Governance)) {
        Write-Host "[$message]: Importing Microsoft.Graph.Identity.Governance module..."
        Import-Module Microsoft.Graph.Identity.Governance -ErrorAction Stop
    }

    if (-not (Get-MgContext)) {
        Write-Host "[$message]: Connecting to Microsoft Graph..."
        Connect-MgGraph -Scopes "EntitlementManagement.ReadWrite.All" -NoWelcome
    }

    $catalog = Get-MgEntitlementManagementCatalog -filter "displayname eq '$CatalogName'"
    if (-not $catalog) {
        throw "Catalog '$CatalogName' not found."
    }  
    $catalogSubstring = $CatalogName -replace '.* - ', ''
    $accessPackageName = $PackageName + " " + $catalogSubstring
    $description = "Access package granting access for '$catalogSubstring' purpose"

    if ($Hidden) {
            $IsHidden = $true
        }
        else {
            $IsHidden = $false
        }
        Write-Host "$message working on Access Package '$accessPackageName'" -ForegroundColor Cyan
        $params = @{
            displayName = $accessPackageName
            description = $description
            isHidden    = $IsHidden
            catalog     = 
            @{
                id = $catalog.id
            }
        }
        $accessPackage = New-MgEntitlementManagementAccessPackage -BodyParameter $params -ErrorAction SilentlyContinue
        
        foreach ($resource in $CatalogResources) {
            $resourceType = $resource.Type
            if ($resourceType -eq "AadGroup") {
                $resourceType = "AadGroup"
                $resourceDisplayName = $resource.displayName
                $resourceRole = $resource.Role
                $resourceObject = Get-MgEntitlementManagementCatalogResource -AccessPackageCatalogId $catalog.Id | Where-Object { $_.displayName -eq $resourceDisplayName }
                $resourceObjectId = $resourceObject.id
                $resourceObjectOriginId = $resourceObject.OriginId
                $resourceObjectRoles = Get-MgEntitlementManagementCatalogResourceRole -AccessPackageCatalogId $catalog.Id -Filter  "(originSystem eq '$resourceType' and resource/id eq '$($resourceObject.id)')" -ExpandProperty "resource"
                $respurceObjectRoleId = $resourceObjectRoles | Where-Object { $_.DisplayName -eq $resourceRole } | select-object -ExpandProperty OriginId            
            } 
            if ($resourceType -eq "AadApplication") {
                $resourceType = "AadApplication"
                $resourceDisplayName = $resource.displayName
                $resourceRole = $resource.Role
                $resourceObject = Get-MgEntitlementManagementCatalogResource -AccessPackageCatalogId $catalog.Id | Where-Object { $_.displayName -eq $resourceDisplayName }
                $resourceObjectId = $resourceObject.id
                $resourceObjectOriginId = $resourceObject.OriginId
                $resourceObjectRoles = Get-MgEntitlementManagementCatalogResourceRole -AccessPackageCatalogId $catalog.Id -Filter "(originSystem eq '$resourceType' and resource/id eq '$($resourceObject.id)')" -ExpandProperty "resource"
                $respurceObjectRoleId = $resourceObjectRoles | Where-Object { $_.DisplayName -eq $resourceRole } | select-object -ExpandProperty OriginId
            }
            if ($resourceType -eq "SharePointOnline") {
                $resourceType = "SharePointOnline"
                $resourceDisplayName = $resource.displayName
                $resourceRole = $resourceDisplayName + " " + $resource.Role + "s"
                $resourceObject = Get-MgEntitlementManagementCatalogResource -AccessPackageCatalogId $catalog.Id | Where-Object { $_.displayName -eq $resourceDisplayName }
                $resourceObjectId = $resourceObject.id
                $resourceObjectOriginId = $resourceObject.OriginId
                $resourceObjectRoles = Get-MgEntitlementManagementCatalogResourceRole -AccessPackageCatalogId $catalog.Id -Filter "(originSystem eq '$resourceType' and resource/id eq '$($resourceObject.id)')" -ExpandProperty "resource"
                $respurceObjectRoleId = $resourceObjectRoles | Where-Object { $_.DisplayName -eq $resourceRole } | select-object -ExpandProperty OriginId
            } 

            Write-Host "$message Updating Access Package '$accessPackageName' with DisplayName '$($resource.displayName)' Resource role '$($resource.Role)' resouce type '$($resource.Type)'" -ForegroundColor cyan
            $params = @{
                role  = @{
                    displayName  = $resourceRole
                    originSystem = $resourceType 
                    originId     = $respurceObjectRoleId
                    resource     = @{
                        id           = $resourceObjectId
                        displayName  = $resourceDisplayName
                        description  = $resourceDisplayName
                        originId     = $resourceObjectOriginId 
                        originSystem = $resourceType 
                    }
                }
                scope = @{
                    displayName  = "Root"
                    description  = "Root Scope"
                    originId     = $catalog.id
                    originSystem = $resourceType 
                    isRootScope  = $true
                }
            }
            #$params | ConvertTo-Json -Depth 3 | Out-String | Write-Host
            Write-Host "$message Access Package '$accessPackageName' Created. " -ForegroundColor Green
            $resource = New-MgEntitlementManagementAccessPackageResourceRoleScope -AccessPackageId $accessPackage.Id -BodyParameter $params | Out-Null
            $output
        }

    if ($EnableLogs) {
        Stop-Transcript
    }
}
catch {
    Write-Error $_
}