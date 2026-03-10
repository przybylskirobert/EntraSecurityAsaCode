# Entra ID Governance as a Code
**Created:** 2025-05-24
** Updated:** 2026-03-10


## Configurations done by this repo
- Configuring Entitlement management Settings using json file 
- Configuring Entitlement management Catalog using json file
- Configuring Entitlement management Conencted Organizations using json file
- Configuring Entitlement management Access Packages using json file
- Configuring Entitlement management Access Reviews using json file
- Configuring Entitlement management PIM for Roles using json file
- Configuring Entitlement management PIM for Groups using json file
- Configuring Entitlement management Terms of Use using json file
- Configuring Lifecycle workkflows using json file


## How to use this repo

### 1. Configuring Entitlement management Settings 

```powershell
./Set-EntraIDELMSettings.ps1 -JsonPath ./JSON/IGA_Workshop.json  -EnableLogs
```

#### Example Result
```powershell
[Set-EntraIDELMSettings.ps1]: 🚀 Starting Entitlement Management settings setup.
[Set-EntraIDELMSettings.ps1]:  ➕ Setting 'externalUserLifecycleAction' to 'blockSignInAndDelete'
[Set-EntraIDELMSettings.ps1]:  ➕ Setting 'durationUntilExternalUserDeletedAfterBlocked' to '30'
[Set-EntraIDELMSettings.ps1]: 🏁 Entitlement Management settings updated successfully.
```

### 2. Configuring Entitlement management Catalog


```powershell
./Set-EntraIDELMCatalog.ps1 -JsonPath ./JSON/IGA_Workshop.json  -EnableLogs
```

#### Example Result
```powershell
[Set-EntraIDELMCatalog.ps1]: 🚀 Starting configuration of Entitlement Management Catalog 'T0-Master'...
[Set-EntraIDELMCatalog.ps1]:  ℹ️  Catalog 'T0-Master' already exists. Using existing one.
[Set-EntraIDELMCatalog.ps1]:   ℹ️  Group 'IGA - All Catalogs - RBAC Owner' already exists.
[Set-EntraIDELMCatalog.ps1]:    ➕ Adding group 'IGA - All Catalogs - RBAC Owner' to catalog 'T0-Master'
[Set-EntraIDELMCatalog.ps1]:   ℹ️  Group 'IGA - All Catalogs - RBAC Reader' already exists.
[Set-EntraIDELMCatalog.ps1]:    ➕ Adding group 'IGA - All Catalogs - RBAC Reader' to catalog 'T0-Master'
[Set-EntraIDELMCatalog.ps1]:   ℹ️  Group 'IGA - Practice Security - RBAC Owner' already exists.
[Set-EntraIDELMCatalog.ps1]:    ➕ Adding group 'IGA - Practice Security - RBAC Owner' to catalog 'T0-Master'
[Set-EntraIDELMCatalog.ps1]:   ℹ️  Group 'IGA - Practice Security - RBAC Reader' already exists.
[Set-EntraIDELMCatalog.ps1]:    ➕ Adding group 'IGA - Practice Security - RBAC Reader' to catalog 'T0-Master'
[Set-EntraIDELMCatalog.ps1]:   ℹ️  Group 'IGA - Practice Security - RBAC AP Manager' already exists.
[Set-EntraIDELMCatalog.ps1]:    ➕ Adding group 'IGA - Practice Security - RBAC AP Manager' to catalog 'T0-Master'
[Set-EntraIDELMCatalog.ps1]:   ℹ️  Group 'IGA - Project X - RBAC Owner' already exists.
[Set-EntraIDELMCatalog.ps1]:    ➕ Adding group 'IGA - Project X - RBAC Owner' to catalog 'T0-Master'
[Set-EntraIDELMCatalog.ps1]:   ℹ️  Group 'IGA - Project X - RBAC Reader' already exists.
[Set-EntraIDELMCatalog.ps1]:    ➕ Adding group 'IGA - Project X - RBAC Reader' to catalog 'T0-Master'
[Set-EntraIDELMCatalog.ps1]:   ℹ️  Group 'IGA - Project X - RBAC AP Manager' already exists.
[Set-EntraIDELMCatalog.ps1]:    ➕ Adding group 'IGA - Project X - RBAC AP Manager' to catalog 'T0-Master'
[Set-EntraIDELMCatalog.ps1]:    ➕ Assigning role 'Owner' to 'Entra ID Global Admins'
[Set-EntraIDELMCatalog.ps1]:    ℹ️  Role 'Catalog owner' already assigned to 'Entra ID Global Admins' in catalog 'T0-Master'. Skipping.
[Set-EntraIDELMCatalog.ps1]: 🏁  Finished processing catalog 'T0-Master'
[Set-EntraIDELMCatalog.ps1]: 🚀 Starting configuration of Entitlement Management Catalog 'T1 - Project X'...
[Set-EntraIDELMCatalog.ps1]:  ℹ️  Catalog 'T1 - Project X' already exists. Using existing one.
[Set-EntraIDELMCatalog.ps1]:   ℹ️  Group 'T1 - Project X' already exists.
[Set-EntraIDELMCatalog.ps1]:    ➕ Adding group 'T1 - Project X' to catalog 'T1 - Project X'
[Set-EntraIDELMCatalog.ps1]:   ℹ️  Group 'T1 - Project X - ADO' already exists.
[Set-EntraIDELMCatalog.ps1]:    ➕ Adding group 'T1 - Project X - ADO' to catalog 'T1 - Project X'
[Set-EntraIDELMCatalog.ps1]:    ➕ Assigning role 'Owner' to 'IGA - Project X - RBAC Owner'
[Set-EntraIDELMCatalog.ps1]:    ℹ️  Role 'Catalog owner' already assigned to 'IGA - Project X - RBAC Owner' in catalog 'T1 - Project X'. Skipping.
[Set-EntraIDELMCatalog.ps1]:    ➕ Assigning role 'Owner' to 'IGA - All Catalogs - RBAC Owner'
[Set-EntraIDELMCatalog.ps1]:    ℹ️  Role 'Catalog owner' already assigned to 'IGA - All Catalogs - RBAC Owner' in catalog 'T1 - Project X'. Skipping.
[Set-EntraIDELMCatalog.ps1]:    ➕ Assigning role 'Reader' to 'IGA - Project X - RBAC Reader'
[Set-EntraIDELMCatalog.ps1]:    ℹ️  Role 'Catalog reader' already assigned to 'IGA - Project X - RBAC Reader' in catalog 'T1 - Project X'. Skipping.
[Set-EntraIDELMCatalog.ps1]:    ➕ Assigning role 'Reader' to 'IGA - All Catalogs - RBAC Reader'
[Set-EntraIDELMCatalog.ps1]:    ℹ️  Role 'Catalog reader' already assigned to 'IGA - All Catalogs - RBAC Reader' in catalog 'T1 - Project X'. Skipping.
[Set-EntraIDELMCatalog.ps1]:    ➕ Assigning role 'PackageManager' to 'IGA - Project X - RBAC AP Manager'
[Set-EntraIDELMCatalog.ps1]:    ℹ️  Role 'AccessPackages manager' already assigned to 'IGA - Project X - RBAC AP Manager' in catalog 'T1 - Project X'. Skipping.
[Set-EntraIDELMCatalog.ps1]: 🏁  Finished processing catalog 'T1 - Project X'
```
### 3. Configuring Entitlement management Connected Organizations

```powershell
./Set-EntraIDELMConnectedOrganizations -JsonPath ./JSON/IGA_Workshop.json  -EnableLogs
```

#### Example Result
```powershell
[Set-EntraIDELMConnectedOrganizations.ps1]: 🚀 Starting Connected Organization 'entrablog.com' congfiguration
[Set-EntraIDELMConnectedOrganizations.ps1]:  🔁 Connected Organization 'entrablog.com' already exists. Skipping.
```
### 4. Configuring Entitlement management Access Packages

```powershell
./New-EntraIDELMAccessPackage.ps1 -JsonPath ./JSON/IGA_Workshop.json  -EnableLogs
```

#### Example Result
```powershell
[New-EntraIDELMAccessPackage.ps1]: 🚀 Working on catalog: 'T0-Master'
[New-EntraIDELMAccessPackage.ps1]:  ℹ️  Access Package 'IGA - All Catalogs - RBAC Owner' already exists. Continuing...
[New-EntraIDELMAccessPackage.ps1]:    ➕ Added/confirmed resource 'IGA - All Catalogs - RBAC Owner' with role 'Member' in access package 'IGA - All Catalogs - RBAC Owner'.
[New-EntraIDELMAccessPackage.ps1]:    🗑️  Removed existing policy 'IGA - All Catalogs - RBAC Owner - Policy'
[New-EntraIDELMAccessPackage.ps1]:    ✅ Created policy 'Policy' for Access Package 'IGA - All Catalogs - RBAC Owner'
[New-EntraIDELMAccessPackage.ps1]:    🗑️  Removed existing policy 'IGA - All Catalogs - RBAC Owner - Policy2'
[New-EntraIDELMAccessPackage.ps1]:    ✅ Created policy 'Policy2' for Access Package 'IGA - All Catalogs - RBAC Owner'
[New-EntraIDELMAccessPackage.ps1]:    🗑️  Removed existing policy 'IGA - All Catalogs - RBAC Owner - Policy3'
[New-EntraIDELMAccessPackage.ps1]:    ✅ Created policy 'Policy3' for Access Package 'IGA - All Catalogs - RBAC Owner'
[New-EntraIDELMAccessPackage.ps1]:    🗑️  Removed existing policy 'IGA - All Catalogs - RBAC Owner - Policy4'
[New-EntraIDELMAccessPackage.ps1]:    ✅ Created policy 'Policy4' for Access Package 'IGA - All Catalogs - RBAC Owner'
[New-EntraIDELMAccessPackage.ps1]:  🏁 Finished processing package 'IGA - All Catalogs - RBAC Owner'
[New-EntraIDELMAccessPackage.ps1]:  ℹ️  Access Package 'IGA - All Catalogs - RBAC Reader' already exists. Continuing...
[New-EntraIDELMAccessPackage.ps1]:    ➕ Added/confirmed resource 'IGA - All Catalogs - RBAC Reader' with role 'Member' in access package 'IGA - All Catalogs - RBAC Reader'.
[New-EntraIDELMAccessPackage.ps1]:    🗑️  Removed existing policy 'IGA - All Catalogs - RBAC Reader - Policy'
[New-EntraIDELMAccessPackage.ps1]:    ✅ Created policy 'Policy' for Access Package 'IGA - All Catalogs - RBAC Reader'
[New-EntraIDELMAccessPackage.ps1]:  🏁 Finished processing package 'IGA - All Catalogs - RBAC Reader'
[New-EntraIDELMAccessPackage.ps1]: 🚀 Working on catalog: 'T1 - Project X'
```

### 5. Configuring Entitlement management Access Reviews

```powershell
./New-EntraIDELMAccessReview.ps1 -JsonPath ./JSON/IGA_Workshop.json -EnableLogs
```

#### Example Result
```powershell
[New-EntraIDELMAccessReview.ps1]: 🚀 Starting access review setup for catalog 'T0-Master'
[New-EntraIDELMAccessReview.ps1]:  🗑️  Removed existing access review 'IGA - All Catalogs - RBAC Owner - AccessReview'
[New-EntraIDELMAccessReview.ps1]:    ✅ Created 'OneTime' access review 'IGA - All Catalogs - RBAC Owner - AccessReview'
[New-EntraIDELMAccessReview.ps1]:    ✅ Created 'Weekly' access review 'IGA - All Catalogs - RBAC Owner - AccessReview2'
[New-EntraIDELMAccessReview.ps1]:    ✅ Created 'Monthly' access review 'IGA - All Catalogs - RBAC Owner - AccessReview3'
[New-EntraIDELMAccessReview.ps1]:  🗑️  Removed existing access review 'IGA - All Catalogs - RBAC Owner - AccessReview4'
[New-EntraIDELMAccessReview.ps1]:    ✅ Created 'Quaterly' access review 'IGA - All Catalogs - RBAC Owner - AccessReview4'
[New-EntraIDELMAccessReview.ps1]:  🗑️  Removed existing access review 'IGA - All Catalogs - RBAC Owner - AccessReview5'
[New-EntraIDELMAccessReview.ps1]:    ✅ Created 'Annually' access review 'IGA - All Catalogs - RBAC Owner - AccessReview5'
[New-EntraIDELMAccessReview.ps1]: 🏁 Finished processing Access Reviews for catalog 'T0-Master'
[New-EntraIDELMAccessReview.ps1]: 🚀 Starting access review setup for catalog 'T1 - Project X'
[New-EntraIDELMAccessReview.ps1]:    ℹ️  No access review configuration found for catalog 'T1 - Project X'. Skipping...
```

### 6. Configuring Entitlement management PIM for Roles

```powershell
./Set-EntraIDPIMRole.ps1 -JsonPath ./JSON/Pim_T0.json -EnableLogs
```

#### Example Result
```powershell
[Set-EntraIDPIMRole.ps1]: 🚀 Starting configuration of PIM Roles
[Set-EntraIDPIMRole.ps1]:  ➕ Working on role 'Application Administrator'
[Set-EntraIDPIMRole.ps1]:    ➕ Configuring 'Expiration_EndUser_Assignment' to 'PT1H'
[Set-EntraIDPIMRole.ps1]:    ➕ Configuring 'Expiration_Admin_Eligibility' to 'P180D'
[Set-EntraIDPIMRole.ps1]:    ➕ Configuring 'Expiration_Admin_Assignment' to 'P180D'
[Set-EntraIDPIMRole.ps1]:    ➕ Configuring 'Enablement_Admin_Assignment' to 'MultiFactorAuthentication Justification'
[Set-EntraIDPIMRole.ps1]:    ➕ Configuring 'Enablement_EndUser_Assignment' to 'MultiFactorAuthentication Justification'
[Set-EntraIDPIMRole.ps1]:    ➕ Configuring role approvers to 'PIM Application Administrator - Approvers'
[Set-EntraIDPIMRole.ps1]:      🔍 Checking if the group 'PIM Application Administrator - Approvers' exists in Microsoft Entra ID.
[Set-EntraIDPIMRole.ps1]:        ℹ️  Group 'PIM Application Administrator - Approvers' already exists.
[Set-EntraIDPIMRole.ps1]:        ℹ️  Group 'PIM Application Administrator - Approvers' is already set as approver. Skipping.
[Set-EntraIDPIMRole.ps1]:      ✅ Approver setup completed.
[Set-EntraIDPIMRole.ps1]:    ➕ Configuring role eligibility for 'PIM Application Administrator - Eligible'
[Set-EntraIDPIMRole.ps1]:      🔍 Checking if group 'PIM Application Administrator - Eligible' exists.
[Set-EntraIDPIMRole.ps1]:        ℹ️  Group 'PIM Application Administrator - Eligible' already exists.
[Set-EntraIDPIMRole.ps1]:        ℹ️  Group 'PIM Application Administrator - Eligible' is already assigned as eligible. Skipping.
[Set-EntraIDPIMRole.ps1]:      ✅ Eligibility setup completed.
[Set-EntraIDPIMRole.ps1]:  ➕ Working on role 'Authentication Policy Administrator'
[Set-EntraIDPIMRole.ps1]:    ➕ Configuring 'Expiration_EndUser_Assignment' to 'PT1H'
[Set-EntraIDPIMRole.ps1]:    ➕ Configuring 'Expiration_Admin_Eligibility' to 'P180D'
[Set-EntraIDPIMRole.ps1]:    ➕ Configuring 'Expiration_Admin_Assignment' to 'P180D'
[Set-EntraIDPIMRole.ps1]:    ➕ Configuring 'Enablement_Admin_Assignment' to 'MultiFactorAuthentication Justification'
[Set-EntraIDPIMRole.ps1]:    ➕ Configuring 'Enablement_EndUser_Assignment' to 'MultiFactorAuthentication Justification'
[Set-EntraIDPIMRole.ps1]:    ➕ Configuring role approvers to 'PIM Authentication Policy Administrator - Approvers'
[Set-EntraIDPIMRole.ps1]:      🔍 Checking if the group 'PIM Authentication Policy Administrator - Approvers' exists in Microsoft Entra ID.
[Set-EntraIDPIMRole.ps1]:        ℹ️  Group 'PIM Authentication Policy Administrator - Approvers' already exists.
[Set-EntraIDPIMRole.ps1]:        ℹ️  Group 'PIM Authentication Policy Administrator - Approvers' is already set as approver. Skipping.
[Set-EntraIDPIMRole.ps1]:      ✅ Approver setup completed.
[Set-EntraIDPIMRole.ps1]:    ➕ Configuring role eligibility for 'PIM Authentication Policy Administrator - Eligible'
[Set-EntraIDPIMRole.ps1]:      🔍 Checking if group 'PIM Authentication Policy Administrator - Eligible' exists.
[Set-EntraIDPIMRole.ps1]:        ℹ️  Group 'PIM Authentication Policy Administrator - Eligible' already exists.
[Set-EntraIDPIMRole.ps1]:        ℹ️  Group 'PIM Authentication Policy Administrator - Eligible' is already assigned as eligible. Skipping.
[Set-EntraIDPIMRole.ps1]:      ✅ Eligibility setup completed.
```

### 7. Configuring Entitlement management PIM for Groups

```powershell
./Set-EntraIDPIMGroup.ps1 -JsonPath ./JSON/PIM_Groups.json -EnableLogs
```

#### Example Result
```powershell
[Set-EntraIDPIMGroup.ps1]: 🚀 Starting configuration of PIM Groups
[Set-EntraIDPIMGroup.ps1]:  ➕ Working on PIM Group 'PAG Group1'
[Set-EntraIDPIMGroup.ps1]:    ℹ️  Group 'PAG Group1' already exists.
[Set-EntraIDPIMGroup.ps1]:    ℹ️  Group 'PAG Group1 - Eligible' already exists.
[Set-EntraIDPIMGroup.ps1]:    ℹ️  Group 'PAG Group1 - Approvers' already exists.
[Set-EntraIDPIMGroup.ps1]:    ℹ️  Eligibility assignment already exists for group 'e130181c-1066-4a7d-a6a2-fe867f1186fb'.
[Set-EntraIDPIMGroup.ps1]:    ➕ Configuring 'Expiration_EndUser_Assignment' to 'PT7H'
[Set-EntraIDPIMGroup.ps1]:    ➕ Configuring 'Expiration_Admin_Eligibility' to 'P180D'
[Set-EntraIDPIMGroup.ps1]:    ➕ Configuring 'Expiration_Admin_Assignment' to 'P180D'
[Set-EntraIDPIMGroup.ps1]:    ➕ Configuring 'Enablement_Admin_Assignment' to 'MultiFactorAuthentication Justification'
[Set-EntraIDPIMGroup.ps1]:    ➕ Configuring 'Enablement_EndUser_Assignment' to 'MultiFactorAuthentication Justification'
[Set-EntraIDPIMGroup.ps1]:    ➕ Configuring role approvers to 'PAG Group1 - Approvers'
[Set-EntraIDPIMGroup.ps1]:    ➕ Configuring role eligibility for 'PAG Group1 - Eligible'
[Set-EntraIDPIMGroup.ps1]:  ✅ PIM Group 'PAG Group1' setup completed.
[Set-EntraIDPIMGroup.ps1]: 🏁  Configuration Completed.
```
### 8. Configuring Entitlement management Terms of Use

```powershell
./New-EntraIDToU.ps1 -JsonPath ./JSON/TermsOfUse.json  -EnableLogs
```

#### Example Result
```powershell
[New-EntraIDToU.ps1]: 🚀 Starting configuration of Terms Of Use 'Terms of Use'...
[New-EntraIDToU.ps1]:    ℹ️ Terms Of Use 'Terms of Use' already exists.
```

### 9. Configuring Lifecycle Workflows  Configuration
```powershell
./New-EntraIDLCWConfig.ps1 -WorkflowScheduleIntervalInHours 1 -SenderDomain "mvp.entrablog.com" -UseCompanyBranding $false
```

#### Example Result
```powershell
```


### 9. Configuring Lifecycle Workflows  Setup
```powershell
$jsonPath = "./JSON/IGA_workshop.json"
$config = Get-Content -Path $jsonPath -Raw | ConvertFrom-Json

foreach ($LCWSetup in $config.LifecycleWorkflowsSetup){
    ./New-EntraIDLCWSetup.ps1 `
	-WorkflowScheduleIntervalInHours $LCWSetup.WorkflowScheduleIntervalInHours `
	-SenderDomain $LCWSetup.SenderDomain `
	-UseCompanyBranding $LCWSetup.UseCompanyBranding`
	-EnableLogs
}
```

#### Example Result
```powershell
```

### 10. Configuring Lifecycle Workflows  Configuration
```powershell

$jsonPath = "./JSON/IGA_workshop.json"
$config = Get-Content -Path $jsonPath -Raw | ConvertFrom-Json

foreach ($LCWConfig in $config.LifecycleWorkflowsConfig){
    ./New-EntraIDLCWConfig.ps1 `
	-DisplayName $LCWConfig.DisplayName `
	-Rule $LCWConfig.Rule `
	-TimeBasedAttribute $LCWConfig.TimeBasedAttribute `
	-OffsetInDays $LCWConfig.OffsetInDays `
	-Template $LCWConfig.Template `
	-WhatIF $LCWConfig.WhatIF `
	-EnableLogs
}
```

#### Example Result
```powershell
```

