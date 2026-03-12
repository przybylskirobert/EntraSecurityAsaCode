
param(
    [Parameter(Mandatory = $false)]
    [switch] $EnableLogs,
    [Parameter(Mandatory = $false)]
    [switch] $BackupSettings,
    [Parameter(Mandatory = $false)]
    [switch] $ConfigurePolicy,
    [Parameter(Mandatory = $false)]
    [string] $SourcesLocation = "./Reference/PolicyAuthorizationPolicyForM365Groups"
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
        Connect-MgGraph -Scopes 'Directory.ReadWrite.All' -NoWelcome
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
        $originalPolicy = (get-MgGroupSetting | where-object {$_.DisplayName -eq "Group.unified"}).values
        $policyMap = @{}
        $originalPolicy | ForEach-Object { $policyMap[$_.Name] = $_.Value }

        $policy = @{
            NewUnifiedGroupWritebackDefault = $policyMap["NewUnifiedGroupWritebackDefault"]
            EnableMIPLabels                 = $policyMap["EnableMIPLabels"]
            CustomBlockedWordsList          = $policyMap["CustomBlockedWordsList"]
            EnableMSStandardBlockedWords    = $policyMap["EnableMSStandardBlockedWords"]
            ClassificationDescriptions      = $policyMap["ClassificationDescriptions"]
            DefaultClassification           = $policyMap["DefaultClassification"]
            PrefixSuffixNamingRequirement   = $policyMap["PrefixSuffixNamingRequirement"]
            AllowGuestsToBeGroupOwner       = $policyMap["AllowGuestsToBeGroupOwner"]
            AllowGuestsToAccessGroups       = $policyMap["AllowGuestsToAccessGroups"]
            GuestUsageGuidelinesUrl         = $policyMap["GuestUsageGuidelinesUrl"]
            GroupCreationAllowedGroupId     = $policyMap["GroupCreationAllowedGroupId"]
            AllowToAddGuests                = $policyMap["AllowToAddGuests"]
            UsageGuidelinesUrl              = $policyMap["UsageGuidelinesUrl"]
            ClassificationList              = $policyMap["ClassificationList"]
            EnableGroupCreation             = $policyMap["EnableGroupCreation"]
        }
        
        $json = $policy | ConvertTo-Json -Depth 10
        $filePath = "$tenantPath/PolicyAuthorizationPolicyForM365Groups_$dateTime.json"
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
            $GroupSettingId = $paramsFromJson.GroupSettingId 
            $params = @{
                values     = @(
                    @{ name = "NewUnifiedGroupWritebackDefault"; value = $paramsFromJson.NewUnifiedGroupWritebackDefault.ToString().ToLower() }
                    @{ name = "EnableMIPLabels";                 value = $paramsFromJson.EnableMIPLabels.ToString().ToLower() }
                    @{ name = "CustomBlockedWordsList";          value = [string]$paramsFromJson.CustomBlockedWordsList }
                    @{ name = "EnableMSStandardBlockedWords";    value = $paramsFromJson.EnableMSStandardBlockedWords.ToString().ToLower() }
                    @{ name = "ClassificationDescriptions";      value = [string]$paramsFromJson.ClassificationDescriptions }
                    @{ name = "DefaultClassification";           value = [string]$paramsFromJson.DefaultClassification }
                    @{ name = "PrefixSuffixNamingRequirement";   value = [string]$paramsFromJson.PrefixSuffixNamingRequirement }
                    @{ name = "AllowGuestsToBeGroupOwner";       value = $paramsFromJson.AllowGuestsToBeGroupOwner.ToString().ToLower() }
                    @{ name = "AllowGuestsToAccessGroups";       value = $paramsFromJson.AllowGuestsToAccessGroups.ToString().ToLower() }
                    @{ name = "GuestUsageGuidelinesUrl";         value = [string]$paramsFromJson.GuestUsageGuidelinesUrl }
                    @{ name = "GroupCreationAllowedGroupId";     value = [string]$paramsFromJson.GroupCreationAllowedGroupId }
                    @{ name = "AllowToAddGuests";                value = $paramsFromJson.AllowToAddGuests.ToString().ToLower() }
                    @{ name = "UsageGuidelinesUrl";              value = [string]$paramsFromJson.UsageGuidelinesUrl }
                    @{ name = "ClassificationList";              value = [string]$paramsFromJson.ClassificationList }
                    @{ name = "EnableGroupCreation";             value = $paramsFromJson.EnableGroupCreation.ToString().ToLower() }
                )
            }
            Update-MgGroupSetting -GroupSettingId $GroupSettingId -BodyParameter $params
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