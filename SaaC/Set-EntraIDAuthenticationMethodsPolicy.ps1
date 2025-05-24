param(
    [Parameter(Mandatory = $false)]
    [switch] $EnableLogs,
    [Parameter(Mandatory = $false)]
    [switch] $BackupSettings,
    [Parameter(Mandatory = $false)]
    [switch] $ConfigurePolicy,
    [Parameter(Mandatory = $false)]    
    [string] $SourcesLocation = "./Reference/AuthenticationMethodPolicy"
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
        Connect-MgGraph -Scopes "Policy.Read.All", "Policy.ReadWrite.AuthenticationMethod", 'Organization.Read.All' -NoWelcome
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
        $filePath = "$tenantPath/AuthenticationMethodsPolicy_$dateTime.json"
        $uri = "beta/authenticationMethodsPolicy"
        $authenticationMethod = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/$uri"  -method GET
        $authenticationMethodJson = $authenticationMethod | ConvertTo-Json -Depth 10
        $authenticationMethodJson | Set-Content -Path $filePath -Encoding UTF8
        Write-Host "$message Actual settings were saved to: '$filePath'"  -ForegroundColor Cyan
    }
    if ($ConfigurePolicy) {
        if (-not $SourcesLocation ) {
            throw "Missing required parameter 'SourcesLocation'"
        }

        foreach ($file in $jsonFiles) {
            $jsonContent = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
            $uri = $jsonContent.uri
            $url = $jsonContent.url
            $name = $jsonContent.name    
            $body = $jsonContent.Config | ConvertTo-Json -Depth 10
            $method = $jsonContent.config.authenticationMethodConfigurations.id
            Write-Host "$message Working on $name - '$method' method" -ForegroundColor Cyan
            Invoke-MgGraphRequest -Uri $uri -Method PATCH -Body $body
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