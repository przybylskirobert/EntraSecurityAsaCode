<#
    Based on this:
    https=//learn.microsoft.com/en-us/graph/api/resources/authorizationpolicy?view=graph-rest-1.0
    https=//learn.microsoft.com/en-us/graph/api/resources/defaultuserrolepermissions?view=graph-rest-1.0
#>

param(
    [Parameter(Mandatory = $false)]
    [switch] $EnableLogs,
    [Parameter(Mandatory = $false)]
    [switch] $BackupSettings,
    [Parameter(Mandatory = $false)]
    [switch] $ConfigurePolicy,
    [Parameter(Mandatory = $false)]
    [string] $SourcesLocation = "./Reference/PolicyAuthorizationPolicy"
)

try {
    $dateTime = (Get-Date).ToString("yyyy_MM-dd-HH_mm_ss")

    if ($EnableLogs) {
        $scriptPath = $MyInvocation.MyCommand.Path
        $scriptDir = Split-Path -Path $scriptPath
        $scriptDir = $scriptDir + "/Logs"
        $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($scriptPath)
        $logFileName = "$scriptName`_$dateTime.log"
        $logFilePath = Join-Path -Path $scriptDir -ChildPath $logFileName
        Start-Transcript -Path $logFilePath -NoClobber -UseMinimalHeader -Append -Force
    }
    $message = "[$($MyInvocation.MyCommand.Name)]: "

    if (-not (Get-Module Microsoft.Graph.Identity.SignIns)) {
        Write-Host "[$message]: Importing Microsoft.Graph module..."
        Import-Module Microsoft.Graph -ErrorAction Stop
    }
    if (-not (Get-MgContext)) {
        Write-Host "[$message]: Connecting to Microsoft Graph..."
        Connect-MgGraph -Scopes 'Policy.ReadWrite.Authorization', 'Organization.Read.All' -NoWelcome
    }
    
    if (!(Test-Path -Path "$SourcesLocation/")) {
        throw "$message The folder '$SourcesLocation' does not exist. Please check the path."
    }

    $jsonFiles = Get-ChildItem -Path $SourcesLocation -Filter "*.json" | Where-Object { $_.FullName -notlike "*\Excluded\*" }
    if ($JsonFiles.Count -eq 0) {
        Write-Error "$message No JSON files found in '$SourcesLocation'."
        exit
    }

    $tenantName = Get-MgOrganization | Select-Object -ExpandProperty DisplayName
    $tenantPath = "./" + $tenantName
    if (!(Test-Path -path ./$tenantName)) {
        New-Item -Path $tenantPath -ItemType Directory  | out-null
    }

    if ($BackupSettings) {
        $originalPolicy = Get-MgPolicyAuthorizationPolicy
        $policy = @{
            AllowEmailVerifiedUsersToJoinOrganization = $originalPolicy.AllowEmailVerifiedUsersToJoinOrganization
            AllowInvitesFrom                          = $originalPolicy.AllowInvitesFrom
            AllowUserConsentForRiskyApps              = $originalPolicy.AllowUserConsentForRiskyApps
            AllowedToSignUpEmailBasedSubscriptions    = $originalPolicy.AllowedToSignUpEmailBasedSubscriptions
            AllowedToUseSspr                          = $originalPolicy.AllowedToUseSspr
            BlockMsolPowerShell                       = $originalPolicy.BlockMsolPowerShell
            GuestUserRoleId                           = $originalPolicy.GuestUserRoleId
            DefaultUserRolePermissions                = @{
                AllowedToCreateTenants                   = $originalPolicy.DefaultUserRolePermissions.AllowedToCreateTenants
                AllowedToCreateSecurityGroups            = $originalPolicy.DefaultUserRolePermissions.AllowedToCreateSecurityGroups
                AllowedToCreateApps                      = $originalPolicy.DefaultUserRolePermissions.AllowedToCreateApps
                AllowedToReadBitlockerKeysForOwnedDevice = $originalPolicy.DefaultUserRolePermissions.AllowedToReadBitlockerKeysForOwnedDevice
                AllowedToReadOtherUsers                  = $originalPolicy.DefaultUserRolePermissions.AllowedToReadOtherUsers
            }
        }
        
        $json = $policy | ConvertTo-Json -Depth 10
        $filePath = "$tenantPath/PolicyAuthorizationPolicy_$dateTime.json"
        $json | Set-Content -Path $filePath -Encoding UTF8
        Write-Host "$message Actual settings were saved to: '$filePath'"  -ForegroundColor Cyan
    }

    if ($ConfigurePolicy) {
        if (-not $SourcesLocation ) {
            throw "Missing required parameter 'SourcesLocation'"
        }
        foreach ($file in $jsonFiles) {
            $jsonContent = Get-Content -Path $file -Raw
            $paramsFromJson = $jsonContent | ConvertFrom-Json
            $url = $paramsFromJson.url
            $name = $paramsFromJson.name   
            $params = @{
                AllowEmailVerifiedUsersToJoinOrganization = $paramsFromJson.AllowEmailVerifiedUsersToJoinOrganization
                AllowInvitesFrom                          = $paramsFromJson.AllowInvitesFrom
                AllowUserConsentForRiskyApps              = $paramsFromJson.AllowUserConsentForRiskyApps
                AllowedToSignUpEmailBasedSubscriptions    = $paramsFromJson.AllowedToSignUpEmailBasedSubscriptions
                AllowedToUseSspr                          = $paramsFromJson.AllowedToUseSspr
                BlockMsolPowerShell                       = $paramsFromJson.BlockMsolPowerShell
                GuestUserRoleId                           = $paramsFromJson.GuestUserRoleId
                DefaultUserRolePermissions                = @{
                    AllowedToCreateTenants                   = $paramsFromJson.DefaultUserRolePermissions.AllowedToCreateTenants
                    AllowedToCreateSecurityGroups            = $paramsFromJson.DefaultUserRolePermissions.AllowedToCreateSecurityGroups
                    AllowedToCreateApps                      = $paramsFromJson.DefaultUserRolePermissions.AllowedToCreateApps
                    AllowedToReadBitlockerKeysForOwnedDevice = $paramsFromJson.DefaultUserRolePermissions.AllowedToReadBitlockerKeysForOwnedDevice
                    AllowedToReadOtherUsers                  = $paramsFromJson.DefaultUserRolePermissions.AllowedToReadOtherUsers
                    PermissionGrantPoliciesAssigned          = $paramsFromJson.DefaultUserRolePermissions.permissionGrantPoliciesAssigned
                }
            }
            Update-MgPolicyAuthorizationPolicy -BodyParameter $params
            Write-Host "$message Updating $name based on json files completed." -ForegroundColor Green
            Write-Host "$message Check this link to review the configuration:" -ForegroundColor Green
            Write-Host "$message $url"  -ForegroundColor Green
        }
    }
    if ($EnableLogs) {
        Stop-Transcript
    }
}
catch {
    Write-Error $_
}