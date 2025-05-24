<#
    $List = @(
        $(New-Object PSObject -Property @{Name = "[Prefix]CA Exclude ALL"}),
        $(New-Object PSObject -Property @{Name = "[Prefix]CA Exclude - 000 - GLOBAL - DENY - Legacy Authentication"}),
        $(New-Object PSObject -Property @{Name = "[Prefix]CA Exclude - 005 - GLOBAL - DENY - Device Code Auth Flow"}),
        $(New-Object PSObject -Property @{Name = "[Prefix]CA Exclude - 010 - GLOBAL - DENY - Device Platforms"}),
        $(New-Object PSObject -Property @{Name = "[Prefix]CA Exclude - 015 - GLOBAL - DENY - Block Countries with exception"}),
        $(New-Object PSObject -Property @{Name = "[Prefix]CA Exclude - 020 - GLOBAL - DENY - Blocked Risky Countries"}),
        $(New-Object PSObject -Property @{Name = "[Prefix]CA Exclude - 025 - GLOBAL - DENY - Service Accounts with exception"}),
        $(New-Object PSObject -Property @{Name = "[Prefix]CA Exclude - 030 - GLOBAL - DENY - Access to Admin Portals for Guests"}),
        $(New-Object PSObject -Property @{Name = "[Prefix]CA Exclude - 035 - GLOBAL - DENY - High Sign-in Risks"}),
        $(New-Object PSObject -Property @{Name = "[Prefix]CA Exclude - 040 - GLOBAL - DENY - High User Risks"}),
        $(New-Object PSObject -Property @{Name = "[Prefix]CA Exclude - 050 - GLOBAL - ALLOW - Merium Sign-in Risks"}),
        $(New-Object PSObject -Property @{Name = "[Prefix]CA Exclude - 055 - GLOBAL - ALLOW - Merium User Risks"}),
        $(New-Object PSObject -Property @{Name = "[Prefix]CA Exclude - 060 - GLOBAL - ALLOW - Admins with PR MFA"}),
        $(New-Object PSObject -Property @{Name = "[Prefix]CA Exclude - 065 - GLOBAL - ALLOW - Mobile apps and desktop clients"}),
        $(New-Object PSObject -Property @{Name = "[Prefix]CA Exclude - 070 - GLOBAL - ALLOW - Access to cloud with MFA"}),
        $(New-Object PSObject -Property @{Name = "[Prefix]CA Exclude - 095 - GLOBAL - ALLOW - Terms of Use"}),
        $(New-Object PSObject -Property @{Name = "[Prefix]CA Exclude - 100 - GLOBAL - CONTROLL - Sign-In Frequency for Admins"}),
        $(New-Object PSObject -Property @{Name = "[Prefix]CA Exclude - 105 - GLOBAL - CONTROLL - Sign-In Frequency for Users"}),
        $(New-Object PSObject -Property @{Name = "[Prefix]CA Exclude - 110 - GLOBAL - CONTROLL - BYOD devices"}),
        $(New-Object PSObject -Property @{Name = "[Prefix]CA Exclude - 115 - GLOBAL - CONTROLL - Register security information"}),
        $(New-Object PSObject -Property @{Name = "[Prefix]CA Include - Service Accounts"}),
        $(New-Object PSObject -Property @{Name = "[Prefix]CA Include - Admins"})
    )
    ./New-EntraIDGroups.ps1 -List $List -Prefix "Formula5 POC"
#>

[CmdletBinding()]
param(
    [parameter(Mandatory = $true)]
    [PSOBject] $List,
    [Parameter(Mandatory = $false)]
    [string] $Prefix,
    [Parameter(Mandatory = $false)]    
    [switch] $EnableLogs
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
                List       = $List
                Prefix     = $Prefix        
                EnableLogs = $EnableLogs
            }
        )
    )

    Write-Host "[$message]: Starting groups creation..." -ForegroundColor Cyan

    if (-not (Get-Module Microsoft.Graph )) {
        Write-Host "[$message]: Importing Microsoft.Graph module..." -ForegroundColor Yellow
        Import-Module Microsoft.Graph -ErrorAction Stop
    }

    if (-not (Get-MgContext)) {
        Write-Host "[$message]: Connecting to Microsoft Graph..." -ForegroundColor Yellow
        Connect-MgGraph -Scopes "Group.ReadWrite.All" -nowelcome    
    }
        
    if ($List -like "*csv*") {
        if (Test-Path -Path $List) {
            Write-Host "Working with CSV File '$List'" -ForegroundColor Cyan
            $groups = Import-CSV -Path $List
        }
    }
    else {
        $groups = $List
    }

    if ($Prefix) {
        $customPrefix = "$Prefix - "
    }
    else {
        $customPrefix = $null
    }    

    foreach ($entry in $groups) {
        $groupName = $entry.Name -replace "\[Prefix\]", $customPrefix
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
    }

    $output

    if ($EnableLogs) {
        Stop-Transcript
    }
}
catch {
    Write-Error $_
}