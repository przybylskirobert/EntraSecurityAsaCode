param(
    [Parameter(Mandatory = $false)]
    [switch] $EnableLogs,
    [Parameter(Mandatory = $false)]
    [switch] $BackupSettings,
    [Parameter(Mandatory = $false)]
    [switch] $ConfigurePolicy,
    [Parameter(Mandatory = $false)]
    [string] $GroupName = "Admin consent requests",
    [Parameter(Mandatory = $false)]    
    [string] $SourcesLocation = "./Reference/AdminConsentRequestPolicy"
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
        Connect-MgGraph -Scopes 'Organization.Read.All', "Policy.ReadWrite.ConsentRequest", "Directory.ReadWrite.All", "Group.ReadWrite.All" -NoWelcome
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
        $filePath = "$tenantPath/adminConsentRequestPolicy_$dateTime.json"
        $uri = "v1.0/policies/adminConsentRequestPolicy"
        $adminConsentSetup = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/$uri"  -method GET
        $adminConsentSetupJson = $adminConsentSetup | ConvertTo-Json -Depth 10
        $adminConsentSetupJson | Set-Content -Path $filePath -Encoding UTF8
        Write-Host "$message Actual settings were saved to: '$filePath'"  -ForegroundColor Cyan
    }
    if ($ConfigurePolicy) {
        if (!$GroupName) {
            throw "$message Missing required parameter 'GroupName'"
        }
        foreach ($file in $jsonFiles) {
            $jsonContent = Get-Content -Path $file.FullName -Raw 
            $groupID = (Get-MgGroup | Where-Object {$_.DisplayName -eq $GroupName}).ID
            if (!$GroupID){
                $mailNickName = ($GroupName -replace '\s', '').ToLower()
                Write-Host  "$message Missing group '$GroupName' in EntraID, creating ..."
                New-MgGroup -DisplayName $GroupName -MailEnabled:$false -MailNickname $mailNickName -SecurityEnabled:$true
            }
            $jsonContent  = $jsonContent -replace "GROUPID", $groupID
            $jsonContent = $jsonContent | ConvertFrom-Json
            $uri = $jsonContent.uri
            $url = $jsonContent.url
            $name = $jsonContent.name    
            $body = $jsonContent.Config | ConvertTo-Json -Depth 10
            Write-Host "$message Configuring $name including reviewers '$GroupName'" -ForegroundColor Cyan
            Invoke-MgGraphRequest -Uri "$uri "-Method Put -Body $body
        }
        Write-Host "$message Updating $name based on json files completed."  -ForegroundColor Green
        Write-Host "$message Check this link to review the configuration:"  -ForegroundColor Green
        Write-Host "$message $url"  -ForegroundColor Green
    }
    if ($EnableLogs) {
        Stop-Transcript
    }
}
catch {
    Write-Error $_
}