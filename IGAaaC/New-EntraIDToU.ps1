[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$JsonPath,

    [Parameter(Mandatory = $false)]
    [switch]$EnableLogs
)

try {
    $message = $MyInvocation.MyCommand.Name

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

    if (-not (Test-Path $JsonPath)) {
        Write-Host "[$message]: " -NoNewline
        Write-Host "❌ JSON file not found at path: $JsonPath" -ForegroundColor Red
        return
    }

    $json = Get-Content -Path $JsonPath -Raw | ConvertFrom-Json
    $DisplayName = $json.DisplayName
    $Language = $json.Language
    $RequireAcknowledgment = $json.RequireAcknowledgment
    $RequireConsentOnEveryDevice = $json.RequireConsentOnEveryDevice
    $ExpireConsents = $json.ExpireConsents
    $ExpireConsentsFrequency = "P$($json.ExpireConsentsFrequency)D"
    $ConsentsFrequency = $json.ConsentsFrequency
    if ($json.StartDate) {
            try {
                $format = "yyyy-MM-dd"
                $culture = [System.Globalization.CultureInfo]::InvariantCulture
                $trimmedDate = $($json.StartDate).Trim()

                $parsedDate = [datetime]::ParseExact($trimmedDate, $format, $culture)
                $startDateFormatted = $parsedDate.ToString("yyyy-MM-ddTHH:mm:ssZ")
            }
            catch {
                Write-Error "❌ Invalid StartDate format. Expected 'yyyy-MM-dd'. Provided: '$($json.StartDate)'"
                return
            }        
    }

    $output = @(
        $(New-Object PSObject -Property @{
                DisplayName                 = $DisplayName; 
                Language                    = $Language ; 
                RequireAcknowledgment       = $RequireAcknowledgment; 
                RequireConsentOnEveryDevice = $RequireConsentOnEveryDevice; 
                ExpireConsents              = $ExpireConsents;
                ExpireConsentsFrequency     = $ExpireConsentsFrequency; 
                ConsentsFrequency           = $ConsentsFrequency; 
                StartDate                   = $startDateFormatted
            }
        )
    )

    if (-not (Get-Module Microsoft.Graph.Identity.Governance)) {
        Write-Host "[$message]: Importing Microsoft.Graph.Identity.Governance module..."
        Import-Module Microsoft.Graph.Identity.Governance -ErrorAction Stop
    }

    if (-not (Get-MgContext)) {
        Write-Host "[$message]: Connecting to Microsoft Graph..."
        Connect-MgGraph -Scopes "Agreement.ReadWrite.All" -NoWelcome
    }

    $isViewingBeforeAcceptanceRequired = $RequireAcknowledgment
    $isPerDeviceAcceptanceRequired = $RequireConsentOnEveryDevice

    $termsExpiration = $null
    $userReacceptRequiredFrequency = $null

    Write-Host "[$message]: " -nonewline
    Write-Host "🚀 Starting configuration of Terms Of Use '$DisplayName'..." -ForegroundColor Cyan

    if ((Get-MgIdentityGovernanceTermsOfUseAgreement | Where-Object { $_.DisplayName -eq $DisplayName }) -eq $null) {

        if ($ExpireConsents) {
            if (-not $ExpireConsentsFrequency -or -not $ConsentsFrequency -or -not $startDateFormatted) {
                Write-Host "[$message]:  " -nonewline
                Write-Host "⚠️ If ExpireConsents is enabled, ExpireConsentsFrequency, ConsentsFrequency, and StartDate are required."
                return
            }

            $termsExpiration = @{
                startDateTime = $startDateFormatted
                frequency     = $ExpireConsentsFrequency
            }
            $userReacceptRequiredFrequency = [System.TimeSpan]::FromDays($ConsentsFrequency)
        }

        $termsOfUse = @{
            displayName                       = $DisplayName
            isViewingBeforeAcceptanceRequired = $isViewingBeforeAcceptanceRequired
            isPerDeviceAcceptanceRequired     = $isPerDeviceAcceptanceRequired
            files                             = @(
                @{
                    fileName  = "$DisplayName.pdf"
                    language  = $Language
                    isDefault = $true
                    fileData  = @{
                        data = [System.Text.Encoding]::ASCII.GetBytes("SGVsbG8gd29ybGQ=//truncated-binary")
                    }
                }
            )
        }

        if ($ExpireConsents) {
            $termsOfUse.termsExpiration = $termsExpiration
            $termsOfUse.userReacceptRequiredFrequency = $userReacceptRequiredFrequency
        }

        try {
            Write-Host "[$message]:    " -nonewline
            Write-Host "➕ Adding new terms of use '$DisplayName'" -ForegroundColor Green

            New-MgIdentityGovernanceTermsOfUseAgreement -BodyParameter $termsOfUse -ErrorAction SilentlyContinue | out-null
            Write-Host "[$message]: " -nonewline
            Write-Host "🏁 Terms of Use '$DisplayName' configuration completed successfully." -ForegroundColor Cyan
        }
        catch {
            Write-Error "Failed to create Terms of Use: $_"
        }
    }
    else {
        Write-Host "[$message]:    " -nonewline
        Write-Host "ℹ️ Terms Of Use '$DisplayName' already exists." -ForegroundColor Gray
    }
    if ($EnableLogs) {
        Stop-Transcript
    }
}
catch {
    Write-Error $_
}