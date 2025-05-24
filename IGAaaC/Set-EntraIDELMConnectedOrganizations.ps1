[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string] $JsonPath,

    [Parameter(Mandatory = $false)]
    [switch] $EnableLogs
)

$message = $MyInvocation.MyCommand.Name

try {
    if ($EnableLogs) {
        $scriptPath = $MyInvocation.MyCommand.Path
        $scriptDir = Join-Path (Split-Path -Path $scriptPath) "Logs"
        if (-not (Test-Path $scriptDir)) { New-Item -ItemType Directory -Path $scriptDir | Out-Null }
        $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($scriptPath)
        $dateTime = (Get-Date).ToString("yyyy_MM-dd HH_mm_ss")
        $logFileName = "$scriptName`_$dateTime.log"
        $logFilePath = Join-Path -Path $scriptDir -ChildPath $logFileName
        Start-Transcript -Path $logFilePath -NoClobber -UseMinimalHeader -Append -Force
    }

    if (-not (Get-Module -Name Microsoft.Graph.Identity.Governance)) {
        Import-Module Microsoft.Graph.Identity.Governance -ErrorAction Stop
    }

    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes "EntitlementManagement.ReadWrite.All" -NoWelcome
    }

    if (-not (Test-Path $JsonPath)) {
        Write-Host "[$message]:  " -NoNewline
        Write-Host "❌ JSON file not found at: $JsonPath" -ForegroundColor Red
        return
    }

    $connectedOrgs = (Get-Content -Path $JsonPath -Raw | ConvertFrom-Json).ConnectedOrganizations

    if (-not $connectedOrgs) {
        Write-Host "[$message]:  " -NoNewline
        Write-Host "⚠️ No connected organizations defined in the JSON file." -ForegroundColor Yellow
        return
    }

    foreach ($org in $connectedOrgs) {
        $DisplayName = $org.DisplayName
        $DomainName  = $org.DomainName
        $State       = $org.State
        
        Write-Host "[$message]: " -NoNewline
        Write-Host "🚀 Starting Connected Organization '$DisplayName' congfiguration" -ForegroundColor Cyan

        $ConfigurationType = if ($DomainName -match '^[0-9a-fA-F-]{36}$') { "TenantID" } else { "DomainName" }

        $existing = Get-MgEntitlementManagementConnectedOrganization | Where-Object { $_.DisplayName -eq $DisplayName }
        if ($existing) {
            Write-Host "[$message]:  " -NoNewline
            Write-Host "🔁 Connected Organization '$DisplayName' already exists. Skipping." -ForegroundColor Gray
            continue
        }
        switch ($ConfigurationType) {
            "DomainName" {
                $identitySources = @(
                    @{
                        "@odata.type" = "#microsoft.graph.domainIdentitySource"
                        domainName    = $DomainName
                        displayName   = $DomainName
                    }
                )
            }
            "TenantID" {
                $identitySources = @(
                    @{
                        "@odata.type" = "#microsoft.graph.azureActiveDirectoryTenant"
                        tenantId      = $DomainName
                        displayName   = $DisplayName
                    }
                )
            }
        }

        $connectedOrganization = @{
            displayName     = $DisplayName
            description     = "Connected Org for $DisplayName"
            state           = $State
            identitySources = $identitySources
        }
        try {
            New-MgEntitlementManagementConnectedOrganization -BodyParameter $connectedOrganization | out-null
            Write-Host "[$message]:   " -NoNewline
            Write-Host "✅ Created Connected Organization '$DisplayName'." -ForegroundColor Green
        }
        catch {
            Write-Host "[$message]:   " -NoNewline
            Write-Host "❌ Failed to create '$DisplayName': $_" -ForegroundColor Red
            return
        }
        Write-Host "[$message]: " -nonewline
        Write-Host "🏁  Finished processing connected organization '$DisplayName'" -ForegroundColor Cyan
    }
    if ($EnableLogs) {
        Stop-Transcript
    }
}
catch {
    Write-Error $_
    if ($EnableLogs) {
        Stop-Transcript
    }
}