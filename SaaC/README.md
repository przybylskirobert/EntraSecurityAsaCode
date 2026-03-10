# Entra ID Security as a Code
**Created:** 2025-05-24


## Configurations done by this repo
- Configuring Admin Consent request Policy
- Configuring Authentication Methods Policy
- Configuring Password Rule Settings
- Configuring Policy Authorization Policy
## How to use this repo


### 1. Configure Admin Consent Request Policy

```powershell
./Set-EntraIDAdminConsentRequestPolicy.ps1 -EnableLogs -BackupSettings -ConfigurePolicy -GroupName "Entra POC - Admin consent requests"
```

#### Example Result
- Group defigned within GroupName parameter has been created and configured as admin consent approvers.

#### Script Logic
1. Script will connect to Entra ID and save actual configuration in json file, in the same time importing reference setup from json

#### Parameters description
| Parameter   | Mandatory   | Description   |
|-------------|-------------|-------------|
| **-BackupSettings**  | No  | using this switch existing configuration backup is saved in 'Tenant Name' catalog|
| **-ConfigurePolicy**   | No | using this parameter we are configuring settings stored in reference files under 'Reference' catalog, used together with SourcesLocation parameter |
| **-GroupName**   | No | group name that should be configured for approvals |
| **-SourcesLocation**  | No | place where reference files are stored.|
| **-EnableLogs**  | No | This will log everything using transcript and save output to [Logs](./Logs) catalog   |

#### To Add 
N/A

#### Example Script Run
```powershell
./Set-EntraIDAdminConsentRequestPolicy.ps1 -EnableLogs -BackupSettings -ConfigurePolicy -GroupName "LAB - Admin consent requests"                      
Transcript started, output file is /ms-entra-id-gov-automation/SaaC/Logs/Set-EntraIDAdminConsentRequestPolicy_2025_05-14-20_47_33.log
[Set-EntraIDAdminConsentRequestPolicy.ps1]:  Actual settings were saved to: './EntraBlog Tenant/adminConsentRequestPolicy_2025_05-14-20_47_33.json'
[Set-EntraIDAdminConsentRequestPolicy.ps1]:  Configuring Admin Consent Request Policy including reviewers 'LAB - Admin consent requests'
[Set-EntraIDAdminConsentRequestPolicy.ps1]:  Updating Admin Consent Request Policy based on json files completed.
[Set-EntraIDAdminConsentRequestPolicy.ps1]:  Check this link to review the configuration:
[Set-EntraIDAdminConsentRequestPolicy.ps1]:  https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ConsentPoliciesMenuBlade/~/AdminConsentSettings
Transcript stopped, output file is /SaaC/Logs/Set-EntraIDAdminConsentRequestPolicy_2025_05-14-20_47_33.log
```

### 2. Configure Authentication Methods Policy

```powershell
./Set-EntraIDAuthenticationMethodsPolicy.ps1 -EnableLogs -BackupSettings -ConfigurePolicy         
```

#### Example Result
- Defigned authorization policies would be configured.

#### Script Logic
1. Script will configure autorization polices according to setupo in reference json files 

#### Parameters description
| Parameter   | Mandatory   | Description   |
|-------------|-------------|-------------|
| **-BackupSettings**  | No  | using this switch existing configuration backup is saved in 'Tenant Name' catalog|
| **-ConfigurePolicy**   | No | using this parameter we are configuring settings stored in reference files under 'Reference' catalog, used together with SourcesLocation parameter |
| **-SourcesLocation**  | No | place where reference files are stored.|
| **-EnableLogs**  | No | This will log everything using transcript and save output to [Logs](./Logs) catalog   |

#### To Add 
N/A

#### Example Script Run
```powershell
./Set-EntraIDAuthenticationMethodsPolicy.ps1 -EnableLogs -BackupSettings -ConfigurePolicy                                            
Transcript started, output file is /SaaC/Logs/Set-EntraIDAuthenticationMethodsPolicy_2025_05-14-20_59_14.log
[Set-EntraIDAuthenticationMethodsPolicy.ps1]:  Actual settings were saved to: './EntraBlog Tenant/AuthenticationMethodsPolicy_2025_05-14-20_59_14.json'
[Set-EntraIDAuthenticationMethodsPolicy.ps1]:  Working on Policy Authorization Policy - 'Email' method
[Set-EntraIDAuthenticationMethodsPolicy.ps1]:  Working on Policy Authorization Policy - 'Fido2' method
[Set-EntraIDAuthenticationMethodsPolicy.ps1]:  Working on Policy Authorization Policy - 'HardwareOath' method
[Set-EntraIDAuthenticationMethodsPolicy.ps1]:  Working on Policy Authorization Policy - 'MicrosoftAuthenticator' method
[Set-EntraIDAuthenticationMethodsPolicy.ps1]:  Working on Policy Authorization Policy - 'QRCodePin' method
[Set-EntraIDAuthenticationMethodsPolicy.ps1]:  Working on Policy Authorization Policy - 'Sms' method
[Set-EntraIDAuthenticationMethodsPolicy.ps1]:  Working on Policy Authorization Policy - 'SoftwareOath' method
[Set-EntraIDAuthenticationMethodsPolicy.ps1]:  Working on Policy Authorization Policy - 'TemporaryAccessPass' method
[Set-EntraIDAuthenticationMethodsPolicy.ps1]:  Working on Policy Authorization Policy - 'Voice' method
[Set-EntraIDAuthenticationMethodsPolicy.ps1]:  Working on Policy Authorization Policy - 'X509Certificate' method
[Set-EntraIDAuthenticationMethodsPolicy.ps1]:  Updating Policy Authorization Policy based on json files completed.
[Set-EntraIDAuthenticationMethodsPolicy.ps1]:  Check this link to review the configuration:
[Set-EntraIDAuthenticationMethodsPolicy.ps1]:  https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods/fromNav/Identity
Transcript stopped, output file is /SaaC/Logs/Set-EntraIDAuthenticationMethodsPolicy_2025_05-14-20_59_14.log
```

### 3. Configure Password Rule Settings

```powershell
./Set-EntraIDPasswordRuleSettings.ps1 -EnableLogs -BackupSettings -ConfigurePolicy
```

#### Example Result
- Defining password rules for entra id tenant

#### Script Logic
1. Script will configure autorization polices according to setupo in reference json files 

#### Parameters description
| Parameter   | Mandatory   | Description   |
|-------------|-------------|-------------|
| **-BackupSettings**  | No  | using this switch existing configuration backup is saved in 'Tenant Name' catalog|
| **-ConfigurePolicy**   | No | using this parameter we are configuring settings stored in reference files under 'Reference' catalog, used together with SourcesLocation parameter |
| **-SourcesLocation**  | No | place where reference files are stored.|
| **-EnableLogs**  | No | This will log everything using transcript and save output to [Logs](./Logs) catalog   |
| **-PassowrdList**  | No | Link to web hosted txt file containing list of the passwords.   |

#### To Add 
N/A

#### Example Script Run
```powershell
./Set-EntraIDPasswordRuleSettings.ps1 -EnableLogs -BackupSettings -ConfigurePolicy
Transcript started, output file is /SaaC/Logs/Set-EntraIDPasswordRuleSettings_2025_05-14-21_22_25.log
[Set-EntraIDPasswordRuleSettings.ps1]:  Actual settings were saved to: './EntraBlog Tenant/PasswordRuleSettings_2025_05-14-21_22_25.json'
[Set-EntraIDPasswordRuleSettings.ps1]:  Configuring Password Rule Settings banned passwords 'entrablogtenant'           
[Set-EntraIDPasswordRuleSettings.ps1]:  Updating Password Rule Settings based on json files completed.
[Set-EntraIDPasswordRuleSettings.ps1]:  Check this link to review the configuration:
[Set-EntraIDPasswordRuleSettings.ps1]:  https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/PasswordProtection
Transcript stopped, output file is /SaaC/Logs/Set-EntraIDPasswordRuleSettings_2025_05-14-21_22_25.log
```

### 4. Configure Policy Authorization Policy

```powershell
./Set-EntraIDPolicyAuthorizationPolicy.ps1 -EnableLogs -ConfigurePolicy -BackupSettings
```

#### Example Result
- Defining authorization policy for tenant.

#### Script Logic
1. Script will the most important settings for Entra ID security point of view. 


#### Parameters description
| Parameter   | Mandatory   | Description   |
|-------------|-------------|-------------|
| **-BackupSettings**  | No  | using this switch existing configuration backup is saved in 'Tenant Name' catalog|
| **-ConfigurePolicy**   | No | using this parameter we are configuring settings stored in reference files under 'Reference' catalog, used together with SourcesLocation parameter |
| **-SourcesLocation**  | No | place where reference files are stored.|
| **-EnableLogs**  | No | This will log everything using transcript and save output to [Logs](./Logs) catalog   |

#### To Add 
N/A

#### Example Script Run
```powershell
./Set-EntraIDPolicyAuthorizationPolicy.ps1 -EnableLogs -ConfigurePolicy -BackupSettings
Transcript started, output file is /SaaC/Logs/Set-EntraIDPolicyAuthorizationPolicy_2025_05-14-21_26_21.log
[Set-EntraIDPolicyAuthorizationPolicy.ps1]:  Actual settings were saved to: './EntraBlog Tenant/PolicyAuthorizationPolicy_2025_05-14-21_26_21.json'
[Set-EntraIDPolicyAuthorizationPolicy.ps1]:  Updating Policy Authorization Policy based on json files completed.
[Set-EntraIDPolicyAuthorizationPolicy.ps1]:  Check this link to review the configuration:
[Set-EntraIDPolicyAuthorizationPolicy.ps1]:  https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserManagementMenuBlade/~/UserSettings/menuId/UserSettings and https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ConsentPoliciesMenuBlade/~/UserSettings
Transcript stopped, output file is /SaaC/Logs/Set-EntraIDPolicyAuthorizationPolicy_2025_05-14-21_26_21.log
```
