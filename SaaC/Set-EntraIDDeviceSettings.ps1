

param(
    [Parameter(Mandatory = $false)]
    [switch] $EnableLogs,
    [Parameter(Mandatory = $false)]
    [switch] $BackupSettings,
    [Parameter(Mandatory = $false)]
    [switch] $ConfigurePolicy,
    [Parameter(Mandatory = $false)]
    [string] $SourcesLocation = "./Reference/deviceRegistrationPolicy"
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

    if (-not (Get-Module Microsoft.Graph )) {
        Write-Host "$message Importing Microsoft.Graph module..." -ForegroundColor Yellow
        Import-Module Microsoft.Graph -ErrorAction Stop
    }
    if (-not (Get-MgContext)) {
        Write-Host "$message Connecting to Microsoft Graph..."
        Connect-MgGraph -Scopes 'Policy.ReadWrite.DeviceConfiguration' -NoWelcome
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
        $originalPolicy = Get-MgPolicyDeviceRegistrationPolicy 
        $policy = @{
            AzureAdJoin = @{
                AllowedToJoin = $originalPolicy.AzureAdJoin.AllowedToJoin
                IsAdminConfigurable = $originalPolicy.AzureAdJoin.IsAdminConfigurable
            }
            AzureAdRegistration = @{
                AllowedToRegister = $originalPolicy.AzureAdRegistration.AllowedToRegister
                IsAdminConfigurable = $originalPolicy.AzureAdRegistration.IsAdminConfigurable
            }
            Id = $originalPolicy.Id
            LocalAdminPassword = @{
                IsEnabled = $originalPolicy.LocalAdminPassword.IsEnabled
            }
            MultiFactorAuthConfiguration = $originalPolicy.MultiFactorAuthConfiguration
            UserDeviceQuota = $originalPolicy.UserDeviceQuota
        }   
        
        $json = $policy | ConvertTo-Json -Depth 10
        $filePath = "$tenantPath/deviceRegistrationPolicy_$dateTime.json"
        $json | Set-Content -Path $filePath -Encoding UTF8
        Write-Host "$message Actual settings were saved to: '$filePath'"  -ForegroundColor Cyan
    }

    if ($ConfigurePolicy) {
        if (-not $SourcesLocation ) {
            throw "Missing required parameter 'SourcesLocation'"
        }

        $localAdminsGoupName = "EntraID-RegisteredDevicesLocalAdmins"
        $localAdminsGroup = Get-MgGroup -Filter "displayName eq '$localAdminsGoupName'" -ConsistencyLevel eventual -CountVariable count

        if (-not $localAdminsGroup) {
            Write-Host "$message  Group '$localAdminsGoupName' does not exist. Creating..." -ForegroundColor Cyan
            $localAdminsGoup = New-MgGroup `
                -DisplayName $localAdminsGoupName `
                -MailEnabled:$false `
                -MailNickname $localAdminsGoupName `
                -SecurityEnabled:$true `
                -Description "Local admins fo registered devices"
            $localAdminsGroupID =   $localAdminsGroup.ID 
        }
        else {
            Write-Host "$message Group '$localAdminsGoupName' already exists." -ForegroundColor Green
            $localAdminsGroupID =   $localAdminsGroup.ID 
        }

        $allowedToJoinToAADGroupName = "EntraID-AllowedToJoinToAAD"
        $allowedToJoinToAADGroup = Get-MgGroup -Filter "displayName eq '$allowedToJoinToAADGroupName'" -ConsistencyLevel eventual -CountVariable count

        if (-not $allowedToJoinToAADGroup) {
                Write-Host "$message  Group '$allowedToJoinToAADGroupName' does not exist. Creating..." -ForegroundColor Cyan
            $localAdminsGoup = New-MgGroup `
                -DisplayName $allowedToJoinToAADGroupName `
                -MailEnabled:$false `
                -MailNickname $allowedToJoinToAADGroupName `
                -SecurityEnabled:$true `
                -Description "Local admins for registered devices"
            $allowedToJoinToAADGroupID =   $allowedToJoinToAADGroup.ID 
        }
        else {
            Write-Host "$message Group '$allowedToJoinToAADGroupName' already exists." -ForegroundColor Green
            $allowedToJoinToAADGroupID =   $allowedToJoinToAADGroup.ID 
        }

        foreach ($file in $jsonFiles) {
            $jsonContent = Get-Content -Path $file -Raw
            $paramsFromJson = $jsonContent | ConvertFrom-Json
            $url = $paramsFromJson.url
            $name = $paramsFromJson.name   
            $params = @{
                azureADRegistration = @{
                    allowedToRegister = @{
                        "@odata.type" = "#microsoft.graph.allDeviceRegistrationMembership"
                    }
                    isAdminConfigurable = $paramsFromJson.azureADRegistration.isAdminConfigurable
                }
                userDeviceQuota = $paramsFromJson.userDeviceQuota
                id = $paramsFromJson.id
                multiFactorAuthConfiguration = $paramsFromJson.multiFactorAuthConfiguration
                azureADJoin = @{
                    allowedToJoin = @{
                        "@odata.type" = "#microsoft.graph.enumeratedDeviceRegistrationMembership"  
                            groups = @($allowedToJoinToAADGroupID)
                    }
                    isAdminConfigurable = $paramsFromJson.azureADJoin.isAdminConfigurable
                    localAdmins = @{
                        enableGlobalAdmins = $paramsFromJson.azureADJoin.localAdmins.enableGlobalAdmins
                        registeringUsers =  @{
                            "@odata.type" =  "#microsoft.graph.enumeratedDeviceRegistrationMembership" 
                            groups = @($localAdminsGroupID)
                        }
                    }
                }
                localAdminPassword = @{
                    isEnabled = $paramsFromJson.localAdminPassword.isEnabled
                }
            } | ConvertTo-Json -Depth 20
            Invoke-MgGraphRequest -Method PUT -Uri "https://graph.microsoft.com/beta/policies/deviceRegistrationPolicy" -Body $params -ContentType "application/json"
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