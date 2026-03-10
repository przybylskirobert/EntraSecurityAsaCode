[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string] $DisplayName,

    [Parameter(Mandatory = $true)]
    [ValidateSet("DomainName", "TenantID")]
    [string] $ConfigurationType,
    
    [Parameter(Mandatory = $false)]
    [string] $DomainName,
    
    [Parameter(Mandatory = $true)]
    [ValidateSet("proposed", "configured")]
    [string] $State,

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
                DisplayName       = $DisplayName; 
                ConfigurationType = $ConfigurationType ; 
                DomainName        = $DomainName; 
                Enabled           = $Enabled
            }
        )
    )

    $message = "[$($MyInvocation.MyCommand.Name)]: "
    if (-not (Get-Module -Name Microsoft.Graph.Identity.Governance)) {
        Write-Host "[$message]: Importing Microsoft.Graph.Identity.Governance module..."
        Import-Module Microsoft.Graph.Identity.Governance -ErrorAction Stop
    }

    if (-not (Get-MgContext)) {
        Write-Host "[$message]: Connecting to Microsoft Graph..."
        Connect-MgGraph -Scopes "EntitlementManagement.ReadWrite.All" -NoWelcome
    }

    $connectedOrganization = @{
        displayName = $DisplayName
        description = $DisplayName
        state       = $State
    }
    if ((get-MgEntitlementManagementConnectedOrganization | where-object { $_.DisplayName -eq $DisplayName }) -eq $null) {
        switch ($ConfigurationType) {
            "DomainName" {
                if (-not $DomainName) {
                    throw "$message You must provide a domain name when ConfigurationType is 'DomainName'."
                }

                $connectedOrganization.identitySources = @(
                    @{
                        '@odata.type' = '#microsoft.graph.domainIdentitySource'
                        domainName    = $DomainName
                        displayName   = $DomainName
                    }
                )
            }
            "TenantID" {
                if (-not $DomainName) {
                    throw "$message You must provide either a TenantID (GUID) or a domain name for 'TenantID' configuration."
                }

                if ($DomainName -notmatch '^[0-9a-fA-F-]{36}$') {
                    Write-Host "$message Resolving domain '$DomainName' to Tenant ID via OpenID metadata..." -ForegroundColor Cyan

                    try {
                        $url = "https://login.microsoftonline.com/$DomainName/.well-known/openid-configuration"
                        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop

                        if ($response.StatusCode -eq 200) {
                            $metadata = $response.Content | ConvertFrom-Json
                            $issuer = $metadata.issuer.TrimEnd('/')
                            $tenantGuid = $issuer -split '/' | Select-Object -Last 1
                            $DomainName = $tenantGuid
                            Write-Host "Resolved Tenant ID: $DomainName" -ForegroundColor Cyan
                        }
                        else {
                            Write-Warning "$message Unexpected status code: $($response.StatusCode). Could not retrieve metadata."
                            return
                        }
                    }
                    catch {
                        Write-Error "$message Failed to retrieve tenant ID for domain '$DomainName': $_"
                        return
                    }
                }

                $connectedOrganization.identitySources = @(
                    @{
                        '@odata.type' = '#microsoft.graph.azureActiveDirectoryTenant'
                        tenantId      = $DomainName
                        displayName   = $DisplayName
                    }
                )
            }
        }
        try {
            New-MgEntitlementManagementConnectedOrganization -BodyParameter $connectedOrganization | Out-Null
            Write-Host "$message Connected Organization '$DisplayName' created successfully." -ForegroundColor Green
            $output
        }
        catch {
            Write-Error "$message Failed to create Connected Organization: $_"
        }
    }
    else {
        Write-Host "$message Connected Organization '$DisplayName' already exists." -ForegroundColor Red
    }
    if ($EnableLogs) {
        Stop-Transcript
    }
}
catch {
    Write-Error $_
}