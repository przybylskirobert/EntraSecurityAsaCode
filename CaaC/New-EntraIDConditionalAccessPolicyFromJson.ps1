[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string] $Prefix,
    [Parameter(Mandatory = $false)]    
    [ValidateSet("Report-Only", "On", "Off")]
    [string] $Mode,
    [Parameter(Mandatory = $false)]    
    [switch] $EnableLogs,
    [Parameter(Mandatory = $false)]    
    [string] $SourcesLocation = "./Sources"
)

try { 
    if ($EnableLogs) {
        $scriptPath = $MyInvocation.MyCommand.Path
        $scriptDir = Split-Path -Path $scriptPath
        $scriptDir = $scriptDir + "/Logs"
        $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($scriptPath)
        $dateTime = (Get-Date).ToString("yyyy_MM-dd_HH_mm_ss")
        $logFileName = "$scriptName`_$dateTime.log"
        $logFilePath = Join-Path -Path $scriptDir -ChildPath $logFileName
        Start-Transcript -Path $logFilePath -NoClobber -UseMinimalHeader -Append -Force
    }

    $message = "[$($MyInvocation.MyCommand.Name)] :"
    $output = @(
        $(New-Object PSObject -Property @{
                Prefix     = $Prefix   
                EnableLogs = $EnableLogs
            }
        )
    )

    if ($Mode -eq "On"){
        $state = "enabled"
    }
    elseif ($mode -eq "Off"){
        $state = "disabled"
    } else {
        $state = "enabledForReportingButNotEnforced"
        $mode = 'Report-Only'
    }
    
    if (!(Test-Path -Path "$SourcesLocation/")) {
        throw "$message The folder '$SourcesLocation' does not exist. Please check the path."
    }
    $jsonFiles = Get-ChildItem -Path $SourcesLocation -Filter "*.json"| Where-Object { $_.FullName -notlike "*\Excluded\*" }
    if ($JsonFiles.Count -eq 0) {
        Write-Error "$message No JSON files found in '$SourcesLocation'."
        exit
    }

    Write-Host "$message Starting named Conditional Access Policy configuration..." -ForegroundColor Cyan

    if (-not (Get-Module Microsoft.Graph )) {
        Write-Host "$message  Importing Microsoft.Graph module..." -ForegroundColor Yellow
        Import-Module Microsoft.Graph -ErrorAction Stop
    }

    if (-not (Get-MgContext)) {
        Write-Host "$message onnecting to Microsoft Graph..." -ForegroundColor Yellow
        Connect-MgGraph -Scopes "Policy.ReadWrite.ConditionalAccess","Application.Read.All" -nowelcome    
    }

    if ($Prefix) {
        $customPrefix = "$Prefix - "
    }
    else {
        $customPrefix = $null
    }    
    Write-Host "$message Generating Users List." -ForegroundColor Cyan
    $users = Get-MGUser -All 
    Write-Host "$message Generating Locations List." -ForegroundColor Cyan
    $locations = Get-MgIdentityConditionalAccessNamedLocation | where-object {$_.DisplayName -like "*$customPrefix*"}

    foreach ($file in $jsonFiles){
        
        $groupName = ($customPrefix + "CA Exclude - " + $file.BaseName)
        $mailNickName = $groupName -replace "-", ""
        $mailNickName = $mailNickName -replace " ", ""
        Write-Host "$message Checking if group '$groupName' exists in tenant.." -ForegroundColor Cyan
        if (!(Get-MgGroup -Filter "DisplayName eq '$groupName'")) {
            Write-Host "$message Creating new group '$groupName'" -ForegroundColor Yellow
            New-MgGroup -DisplayName $groupName -MailEnabled:$false -MailNickname $mailNickName -SecurityEnabled:$true | out-Null
        }
        else {
            Write-Host "$message Group '$groupName' already exists in tenant." -ForegroundColor Green
        }

        $groups = Get-MgGroup -All | Where-Object {$_.DisplayName -like "*$customPrefix*"}    
        
        $params = @()
        $params = Get-Content -Path $file.FullName -Raw 
        $params = $params -replace "\[Prefix\]", $customPrefix
        $params = $params -replace "\[State\]", $state
        
        $policyName = ($params  | ConvertFrom-Json).displayName

        if (!(get-MgIdentityConditionalAccessPolicy | where-object {$_.DisplayName -eq $policyName})){
            Write-Host "$message Working on Conditional Access Policy '$policyName'" -ForegroundColor Cyan
            
            $groupObjects = @()
            foreach ($group in $groups){
                $groupObjects += [PSCustomObject]@{
                    GroupName = $group.DisplayName
                    GroupID   = $group.Id
                }
            }

            foreach ($object in $groupObjects){
                $params = $params -replace $object.GroupName, $object.GroupID
            }

            $userObjects = @()
            foreach ($user in $users){
                $userObjects += [PSCustomObject]@{
                    UserName = $user.DisplayName
                    UserID   = $user.Id
                }
            }
            foreach ($object in $userObjects){
                $params = $params -replace $object.DisplayName, $object.Id
            }

            $namedLocations = @()
            foreach ($location in $locations){
                $namedLocations += [PSCustomObject]@{
                    LocationName = $location.DisplayName
                    LocationID   = $location.id
                }
            }
            foreach ($object in $namedLocations){
                $params = $params -replace $object.LocationName, $object.LocationID
            }
            New-MgIdentityConditionalAccessPolicy -BodyParameter $params | Out-Null
            Write-Host "$message Conditional Access Policy '$policyName' in '$Mode' mode created." -ForegroundColor Yellow
        }
        else {
            Write-Host "$message Conditional Access Policy '$policyName' already exists." -ForegroundColor Green

        }
    }
    $output
    if ($EnableLogs) {
        Stop-Transcript
    }
}
catch {
    Write-Error $_
}