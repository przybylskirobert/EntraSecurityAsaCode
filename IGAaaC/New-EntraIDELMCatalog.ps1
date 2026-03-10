param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("Internal", "SharedWithExternals")]
    [string] $CatalogType,

    [Parameter(Mandatory = $true)]
    [string] $NameSuffix,

    [Parameter(Mandatory = $false)]
    [switch]$Published,

    [Parameter(Mandatory = $false)]
    [string] $ExternalsName,

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
                CatalogType  = $CatalogType; 
                NameSuffix = $NameSuffix ; 
                Published   = $Published; 
                ExternalsName   = $ExternalsName; 
                EnableLogs      = $EnableLogs
            }
        )
    )
    $message = "[$($MyInvocation.MyCommand.Name)]: "
    if (-not (Get-Module -Name Microsoft.Graph.Identity.Governance)) {
        Import-Module Microsoft.Graph.Identity.Governance
    }
    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes "EntitlementManagement.ReadWrite.All" -NoWelcome
    }

    
    if ($Published) {
        $state = "published"
    }
    else {
        $state = "unpublished"
    }

    if ($CatalogType -eq "Internal") {
        $isExternallyVisible = $false
        $displayName = "Internal Use - $NameSuffix"
        $description = "Catalog created for Internal use only purpose, requested for '$nameSuffix'"
    }
    else {
        $isExternallyVisible = $true
        $displayName = "External Collaboration - 3rd party providers - $ExternalsName - $NameSuffix"
        $description = "Catalog created for External Collaboration with 3rd party partners - '$ExternalsName', reqursted for '$NameSuffix'"
    }

    If ((Get-MgEntitlementManagementCatalog | Where-Object {$_.DisplayName -eq $displayName}) -eq $null){
        $catalog = @{
            displayName         = $DisplayName
            description         = $Description
            state               = $state
            isExternallyVisible = $isExternallyVisible
        }

        try {
            New-MgEntitlementManagementCatalog -BodyParameter $catalog | out-null
            Write-Host "$message Catalog '$DisplayName' created successfully." -ForegroundColor Cyan
            $output 
        }
        catch {
            Write-Error "$message Failed to create Catalog: $_"
        }
    }
    else {
        Write-Host "$message Catalog '$DisplayName' already exists." -ForegroundColor Red
    }
    if ($EnableLogs) {
        Stop-Transcript
    }
}
catch {
    Write-Error $_
}