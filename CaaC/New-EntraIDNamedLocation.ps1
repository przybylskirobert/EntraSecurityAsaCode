<#
    $List = @(
        $(New-Object PSObject -Property @{Name = "Allowed Countries";CountryList = "PL,IN,US";IP= ""}),
        $(New-Object PSObject -Property @{Name = "Risky Countries";CountryList = "BY,KP,RU,IR";IP = ""}),
        $(New-Object PSObject -Property @{Name = "Trusted IPs for service accounts";CountryList = "";IP = "109.241.14.130/32"})
    )
    ./New-EntraIDNamedLocation.ps1 -List $List -Prefix "Formula5 POC"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
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
                Prefix     = $Prefix
                List       = $List        
                EnableLogs = $EnableLogs
            }
        )
    )

    Write-Host "$message Starting named locations creation..." -ForegroundColor Cyan

    if (-not (Get-Module Microsoft.Graph )) {
        Write-Host "$message Importing Microsoft.Graph module..." -ForegroundColor Yellow
        Import-Module Microsoft.Graph -ErrorAction Stop
    }

    if (-not (Get-MgContext)) {
        Write-Host "$message Connecting to Microsoft Graph..." -ForegroundColor Yellow
        Connect-MgGraph -Scopes "Policy.ReadWrite.ConditionalAccess" -nowelcome    
    }

    foreach ($entry in $list) {
        $displayName = if ($Prefix) {
            "$Prefix - $($entry.Name)"
        }
        else {
            $Name
        }
        if (!(Get-MgIdentityConditionalAccessNamedLocation | Where-Object {$_.DisplayName -eq $displayName})){
            if ($entry.CountryList -and !$entry.IP) {
                $countriesAndRegions = $entry.CountryList.Split(',')

                $params = @{
                    "@odata.type"                     = "#microsoft.graph.countryNamedLocation"
                    DisplayName                       = $displayName
                    CountriesAndRegions               = $countriesAndRegions
                    IncludeUnknownCountriesAndRegions = $true
                }
            }
            else {
                $cidrAddress = $entry.IP
                $params = @{
                    "@odata.type" = "#microsoft.graph.ipNamedLocation"
                    DisplayName   = $displayName
                    IsTrusted     = $true
                    IpRanges      = @(
                        @{
                            "@odata.type" = "#microsoft.graph.iPv4CidrRange"
                            CidrAddress   = $cidrAddress 
                        }
                    )
                }
            }
            #$params | ConvertTo-Json -Depth 10 -Compress
            Write-Host "$message Creating new Conditional Access Named Location '$displayName'" -ForegroundColor Yellow
            New-MgIdentityConditionalAccessNamedLocation -BodyParameter $params | Out-Null
        }
        else {
            Write-Host "$message Conditional Access Named Location '$displayName' already exists." -ForegroundColor Green

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