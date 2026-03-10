param (
    [Parameter(Mandatory = $true)]
    [string]$DisplayName,

    [Parameter(Mandatory = $false)]
    [string]$Language,

    [Parameter(Mandatory = $true)]
    [switch]$RequireAcknowledgment,

    [Parameter(Mandatory = $false)]
    [switch]$RequireConsentOnEveryDevice,

    [Parameter(Mandatory = $false)]
    [switch]$ExpireConsents,

    [Parameter(Mandatory = $false)]
    [ValidateSet("P30D", "P90D", "P180D", "P365D")]
    [string]$ExpireConsentsFrequency,

    [Parameter(Mandatory = $false)]
    [string]$ConsentsFrequency,

    [Parameter(Mandatory = $false, HelpMessage = "Provide date in yyyy.MM.dd format")]
    [string]$StartDate,
    
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
                DisplayName                 = $DisplayName; 
                Language                    = $Language ; 
                RequireAcknowledgment       = $RequireAcknowledgment; 
                RequireConsentOnEveryDevice = $RequireConsentOnEveryDevice; 
                ExpireConsents              = $ExpireConsents;
                ExpireConsentsFrequency     = $ExpireConsentsFrequency; 
                ConsentsFrequency           = $ConsentsFrequency; 
                StartDate                   = $StartDate;
                Enabled                     = $Enabled
            }
        )
    )
    $message = "[$($MyInvocation.MyCommand.Name)]: "

    if (-not (Get-Module Microsoft.Graph.Identity.Governance)) {
        Write-Host "[$message]: Importing Microsoft.Graph.Identity.Governance module..."
        Import-Module Microsoft.Graph.Identity.Governance -ErrorAction Stop
    }

    if (-not (Get-MgContext)) {
        Write-Host "[$message]: Connecting to Microsoft Graph..."
        Connect-MgGraph -Scopes "Agreement.ReadWrite.All" -NoWelcome
    }

    $isViewingBeforeAcceptanceRequired = $RequireAcknowledgment.IsPresent
    $isPerDeviceAcceptanceRequired = $RequireConsentOnEveryDevice.IsPresent

    $termsExpiration = $null
    $userReacceptRequiredFrequency = $null

    if ((Get-MgIdentityGovernanceTermsOfUseAgreement | Where-Object { $_.DisplayName -eq $DisplayName }) -eq $null) {
        if ($StartDate) {
            $format = "yyyy.MM.dd"
            $culture = [System.Globalization.CultureInfo]::InvariantCulture
            $date = ([datetime]::ParseExact($StartDate, $format, $culture)).ToString("yyyy-MM-ddTHH:mm:ssZ")
        }

        if ($ExpireConsents) {
            if (-not $ExpireConsentsFrequency -or -not $ConsentsFrequency -or -not $StartDate) {
                Write-Error -Message "If ExpireConsents is enabled, ExpireConsentsFrequency, ConsentsFrequency, and StartDate are required."
                return
            }

            $termsExpiration = @{
                startDateTime = $date
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
            New-MgIdentityGovernanceTermsOfUseAgreement -BodyParameter $termsOfUse | out-null
            Write-Host "$message Terms of Use configuration completed successfully." -ForegroundColor Green
            $output
        }
        catch {
            Write-Error "Failed to create Terms of Use: $_"
        }
    }
    else {
        Write-Host "$message Terms Of Use  '$DisplayName' already exists." -ForegroundColor Red
    }
    if ($EnableLogs) {
        Stop-Transcript
    }
}
catch {
    Write-Error $_
}