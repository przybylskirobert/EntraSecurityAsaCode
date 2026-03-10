# Conditional Access as a Code
**Created:** 2025-05-24


## Policies created by this repo

File declarations for policies described here could be found here: [Open Sources Folder](./Sources/)
- 000 - GLOBAL - DENY - Legacy Authentication
- 005 - GLOBAL - DENY - Device Code Auth Flow
- 010 - GLOBAL - DENY - Device Platforms
- 015 - GLOBAL - DENY - Block Countries with exception
- 020 - GLOBAL - DENY - Blocked Risky Countries
- 025 - GLOBAL - DENY - Service Accounts with exception
- 030 - GLOBAL - DENY - Access to Admin Portals for Guests
- 035 - GLOBAL - DENY - High Sign-in Risks
- 040 - GLOBAL - DENY - High User Risks
- 050 - GLOBAL - ALLOW - Medium Sign-in Risks
- 055 - GLOBAL - ALLOW - Medium User Risks
- 060 - GLOBAL - ALLOW - Admins with PR MFA
- 065 - GLOBAL - ALLOW - Mobile apps and desktop clients
- 070 - GLOBAL - ALLOW - Users with MFA
- 100 - GLOBAL - CONTROL - Sign-In Frequency for Admins
- 105 - GLOBAL - CONTROL - Sign-In Frequency for Users
- 110 - GLOBAL - CONTROL - BYOD devices
- 115 - GLOBAL - CONTROL - Register security information

Excluded declarations for policies could be found here: [Open Excluded Folder](./Sources/Excluded)

Policy numbers from 000-049 are reserved for DENY Actions  
Policy numbers from 050-099 are reserved for ALLOW Actions  
Policy numbers from 100-149 are reserved for CONTROL Actions  

## How to use this repo

### 1. Scripts are using 'Prefix" that could be added at the beggining of:
- Named Locations
- Groups
- Conditional Access Policies 
 
**In examples below "EntraBlog POC" prefix will be added.**


### 2. Create Named Locations

```powershell
$List = @(
    $(New-Object PSObject -Property @{Name = "Allowed Countries";CountryList = "PL,CA,US";IP= ""}),
    $(New-Object PSObject -Property @{Name = "Risky Countries";CountryList = "BY,KP,RU,IR";IP = ""}),
    $(New-Object PSObject -Property @{Name = "Trusted IPs for service accounts";CountryList = "";IP = "109.241.14.130/32"})
)
./New-EntraIDNamedLocation.ps1 -List $List -Prefix "Ennoble Care" -EnableLogs
```
#### Example Result
- EntraBlog POC - Allowed Countries
- EntraBlog POC - Risky Countries
- EntraBlog POC - Trusted IPs for service accounts

#### Script Logic

1. **New Location** is created based on the value of the `Name` property from the `$List` object.
2. Based on additional properties:
   - If `CountryList` is set:
     - Configure **CountriesAndRegions**.
   - If `IP` is set:
     - Create **CidrAddress**.
3. In case that **Prefix** parameter is set then naming location will look like `Prefix - Location Name` else `Location Name`

#### Parameters description

| Parameter   | Mandatory   | Description   |
|-------------|-------------|-------------|
| **-List**  | Yes  | This is object array that has 3 properties: Name, CountryList and IP |
| **-Prefix**   | No | This will add prefix to the objects names, in case that this parameter is not declared names will start as it is configured in **$List**  |
| **-EnableLogs**  | No  | This will log everything using transcript and save output to [Logs](./Logs) catalog   |

#### Example Script Run
```powershell
Transcript started, output file is /formula5/CaaC/Logs/New-EntraIDNamedLocation_2025_01-24_13_43_07.log
[New-EntraIDNamedLocation.ps1] : Starting named locations creation...
[New-EntraIDNamedLocation.ps1] : Creating new Conditional Access Named Location 'Ennoble Care - Allowed Countries'
[New-EntraIDNamedLocation.ps1] : Creating new Conditional Access Named Location 'Ennoble Care - Risky Countries'
[New-EntraIDNamedLocation.ps1] : Creating new Conditional Access Named Location 'Ennoble Care  - Trusted IPs for service accounts'

List
----                                                                                                                                           
{@{Name=Allowed Countries; CountryList=PL,IN,US; IP=}, @{Name=Risky Countries; CountryList=BY,KP,RU,IR; IP=}, @{Name=Trusted IPs for service a…
Transcript stopped, output file is /formula5/CaaC/Logs/New-EntraIDNamedLocation_2025_01-24_13_43_07.log
```

### 3. Create required use-for-all groups
```powershell
$List = @(
    $(New-Object PSObject -Property @{Name = "[Prefix]CA Exclude ALL"}),
    $(New-Object PSObject -Property @{Name = "[Prefix]CA Include - Service Accounts"}),
    $(New-Object PSObject -Property @{Name = "[Prefix]CA Exclude - Service Accounts"}),
    $(New-Object PSObject -Property @{Name = "[Prefix]CA Include - Admins"})
)
./New-EntraIDGroups.ps1 -List $List -Prefix "Ennoble Care" -EnableLogs
```
#### Example Result
- EntraBlog POC - CA Exclude ALL
- EntraBlog POC - CA Include - Service Accounts
- EntraBlog POC - CA Exclude - Service Accounts
- EntraBlog POC - CA Include - Admins

#### Script Logic

1. **New Group** is created based on the value of the `Name` property from the `$List` object.
2. In case that **Prefix** parameter is set then group name will look like `Prefix - Group name` else `Group name`


#### Parameters description

| Parameter   | Mandatory   | Description   |
|-------------|-------------|-------------|
| **-List**  | Yes  | This is object array that has Name property assigned|
| **-Prefix**   | No | This will add prefix to the objects names, in case that this parameter is not declared names will start as it is configured in **$List**  |
| **-EnableLogs**  | No  | This will log everything using transcript and save output to [Logs](./Logs) catalog   |

#### Script Logic

1. **New Location** is created based on the value of the `Name` property from the `$List` object.
2. Based on additional properties:
   - If `CountryList` is set:
     - Configure **CountriesAndRegions**.
   - If `IP` is set:
     - Create **CidrAddress**.
     

#### Example Script Run

```powershell
Transcript started, output file is /formula5/CaaC/Logs/New-EntraIDGroups_2025_01-24_13_45_29.log
[[New-EntraIDGroups.ps1] :]: Starting groups creation...
[New-EntraIDGroups.ps1] : Checking if group 'EntraBlog POC - CA Exclude ALL' exists in tenant..
[New-EntraIDGroups.ps1] : Creating new group 'EntraBlog POC - CA Exclude ALL'
[New-EntraIDGroups.ps1] : Checking if group 'EntraBlog POC - CA Include - Service Accounts' exists in tenant..
[New-EntraIDGroups.ps1] : Creating new group 'EntraBlog POC - CA Include - Service Accounts'
[New-EntraIDGroups.ps1] : Checking if group 'EntraBlog POC - CA Exclude - Service Accounts' exists in tenant..
[New-EntraIDGroups.ps1] : Creating new group 'EntraBlog POC - CA Exclude - Service Accounts'
[New-EntraIDGroups.ps1] : Checking if group 'EntraBlog POC - CA Include - Admins' exists in tenant..
[New-EntraIDGroups.ps1] : Creating new group 'EntraBlog POC - CA Include - Admins'

List
----                                                                                                                                           
{@{Name=[Prefix]CA Exclude ALL}, @{Name=[Prefix]CA Include - Service Accounts}, @{Name=[Prefix]CA Exclude - Service Accounts}, @{Name=[Prefix]…
Transcript stopped, output file is /formula5/CaaC/Logs/New-EntraIDGroups_2025_01-24_13_45_29.log
```

### 4. When having groups and named locations we can implement conditional access policies 

```powershell
./New-EntraIDConditionalAccessPolicyFromJson.ps1 -Prefix "Ennoble Care" -Mode "Report-Only" -EnableLogs -SourcesLocation "./Sources"
```

#### Example Result
- EntraBlog POC - 000 - GLOBAL - DENY - Legacy Authentication
- EntraBlog POC - 005 - GLOBAL - DENY - Device Code Auth Flow
- EntraBlog POC - 010 - GLOBAL - DENY - Device Platforms
- EntraBlog POC - 015 - GLOBAL - DENY - Block Countries with exception
- EntraBlog POC - 020 - GLOBAL - DENY - Blocked Risky Countries
- EntraBlog POC - 025 - GLOBAL - DENY - Service Accounts with exception
- EntraBlog POC - 030 - GLOBAL - DENY - Access to Admin Portals for Guests
- EntraBlog POC - 035 - GLOBAL - DENY - High Sign-in Risks
- EntraBlog POC - 040 - GLOBAL - DENY - High User Risks
- EntraBlog POC - 050 - GLOBAL - ALLOW - Medium Sign-in Risks
- EntraBlog POC - 055 - GLOBAL - ALLOW - Medium User Risks
- EntraBlog POC - 060 - GLOBAL - ALLOW - Admins with PR MFA
- EntraBlog POC - 065 - GLOBAL - ALLOW - Mobile apps and desktop clients
- EntraBlog POC - 070 - GLOBAL - ALLOW - Users with MFA
- EntraBlog POC - 100 - GLOBAL - CONTROL - Sign-In Frequency for Admins
- EntraBlog POC - 105 - GLOBAL - CONTROL - Sign-In Frequency for Users
- EntraBlog POC - 110 - GLOBAL - CONTROL - BYOD devices
- EntraBlog POC - 115 - GLOBAL - CONTROL - Register security information


#### Script Logic

1. **New Conditional Access Policy** is created based on the value of the json files stored in `Sources` folder.
2. Policy names are generated based on the following logic 

    2.1. If `Prefix` parameter is set it will add this at the beggining of policy name 

    2.2 Policy `Mode` can be controled, default setting is `Report-Only`

    2.2.1 If `Mode` is set to `Report-Only` policy will be working in report mod

    2.2.2 If `Mode` is set to `On` policy will be `enforced`

    2.2.2 If `Mode` is set to `Off` policy will be `disabled`
3. Policy Exclusions are made based on group names that are matching to policy names

    3.1 For Policy called `EntraBlog POC - 000 - GLOBAL - DENY - Legacy Authentication`, `EntraBlog POC - CA Exclude ALL` use-for-all group is exccluded, and dedicated group `EntraBlog POC - CA Exclude - 000 - GLOBAL - DENY - Legacy Authentication` for specific policy as well. 


#### Parameters description

| Parameter   | Mandatory   | Description   |
|-------------|-------------|-------------|
| **-Prefix**   | No | This parameter will add prefix to the objects names, in case that this parameter is not declared names will start as per json file name. |
| **-Mode**  | No  | This parameter will configure Policy mode, possible options Report-Only, Off, On  |
| **-EnableLogs**  | No  | This will log everything using transcript and save output to [Logs](./Logs) catalog   |
| **-SourcesLocation**  | No  | This parameter allows to provide json files from different location   |

#### Example Script Run
```powershell
Transcript started, output file is /formula5/CaaC/Logs/New-EntraIDConditionalAccessPolicyFromJson_2025_01-24_13_52_25.log
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Starting named Conditional Access Policy configuration...
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Generating Users List.
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Generating Locations List.
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Checking if group 'EntraBlog POC - CA Exclude - 000 - GLOBAL - DENY - Legacy Authentication' exists in tenant..
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Creating new group 'EntraBlog POC - CA Exclude - 000 - GLOBAL - DENY - Legacy Authentication'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Working on Conditional Access Policy 'EntraBlog POC - 000 - GLOBAL - DENY - Legacy Authentication'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Conditional Access Policy 'EntraBlog POC - 000 - GLOBAL - DENY - Legacy Authentication' in 'Report-Only' mode created.
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Checking if group 'EntraBlog POC - CA Exclude - 005 - GLOBAL - DENY - Device Code Auth Flow' exists in tenant..
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Creating new group 'EntraBlog POC - CA Exclude - 005 - GLOBAL - DENY - Device Code Auth Flow'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Working on Conditional Access Policy 'EntraBlog POC - 005 - GLOBAL - DENY - Device Code Auth Flow'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Conditional Access Policy 'EntraBlog POC - 005 - GLOBAL - DENY - Device Code Auth Flow' in 'Report-Only' mode created.
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Checking if group 'EntraBlog POC - CA Exclude - 010 - GLOBAL - DENY - Device Platforms' exists in tenant..
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Creating new group 'EntraBlog POC - CA Exclude - 010 - GLOBAL - DENY - Device Platforms'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Working on Conditional Access Policy 'EntraBlog POC - 010 - GLOBAL - DENY - Device Platforms'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Conditional Access Policy 'EntraBlog POC - 010 - GLOBAL - DENY - Device Platforms' in 'Report-Only' mode created.
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Checking if group 'EntraBlog POC - CA Exclude - 015 - GLOBAL - DENY - Block Countries with exception' exists in tenant..
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Creating new group 'EntraBlog POC - CA Exclude - 015 - GLOBAL - DENY - Block Countries with exception'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Working on Conditional Access Policy 'EntraBlog POC - 015 - GLOBAL - DENY - Block Countries with exception'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Conditional Access Policy 'EntraBlog POC - 015 - GLOBAL - DENY - Block Countries with exception' in 'Report-Only' mode created.
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Checking if group 'EntraBlog POC - CA Exclude - 020 - GLOBAL - DENY - Blocked Risky Countries' exists in tenant..
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Creating new group 'EntraBlog POC - CA Exclude - 020 - GLOBAL - DENY - Blocked Risky Countries'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Working on Conditional Access Policy 'EntraBlog POC - 020 - GLOBAL - DENY - Blocked Risky Countries'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Conditional Access Policy 'EntraBlog POC - 020 - GLOBAL - DENY - Blocked Risky Countries' in 'Report-Only' mode created.
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Checking if group 'EntraBlog POC - CA Exclude - 025 - GLOBAL - DENY - Service Accounts with exception' exists in tenant..
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Creating new group 'EntraBlog POC - CA Exclude - 025 - GLOBAL - DENY - Service Accounts with exception'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Working on Conditional Access Policy 'EntraBlog POC - 025 - GLOBAL - DENY - Service Accounts with exception'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Conditional Access Policy 'EntraBlog POC - 025 - GLOBAL - DENY - Service Accounts with exception' in 'Report-Only' mode created.
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Checking if group 'EntraBlog POC - CA Exclude - 030 - GLOBAL - DENY - Access to Admin Portals for Guests' exists in tenant..
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Creating new group 'EntraBlog POC - CA Exclude - 030 - GLOBAL - DENY - Access to Admin Portals for Guests'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Working on Conditional Access Policy 'EntraBlog POC - 030 - GLOBAL - DENY - Access to Admin Portals for Guests'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Conditional Access Policy 'EntraBlog POC - 030 - GLOBAL - DENY - Access to Admin Portals for Guests' in 'Report-Only' mode created.
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Checking if group 'EntraBlog POC - CA Exclude - 035 - GLOBAL - DENY - High Sign-in Risks' exists in tenant..
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Creating new group 'EntraBlog POC - CA Exclude - 035 - GLOBAL - DENY - High Sign-in Risks'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Working on Conditional Access Policy 'EntraBlog POC - 035 - GLOBAL - DENY - High Sign-in Risks'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Conditional Access Policy 'EntraBlog POC - 035 - GLOBAL - DENY - High Sign-in Risks' in 'Report-Only' mode created.
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Checking if group 'EntraBlog POC - CA Exclude - 040 - GLOBAL - DENY - High User Risks' exists in tenant..
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Creating new group 'EntraBlog POC - CA Exclude - 040 - GLOBAL - DENY - High User Risks'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Working on Conditional Access Policy 'EntraBlog POC - 040 - GLOBAL - DENY - High User Risks'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Conditional Access Policy 'EntraBlog POC - 040 - GLOBAL - DENY - High User Risks' in 'Report-Only' mode created.
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Checking if group 'EntraBlog POC - CA Exclude - 050 - GLOBAL - ALLOW - Medium Sign-in Risks' exists in tenant..
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Creating new group 'EntraBlog POC - CA Exclude - 050 - GLOBAL - ALLOW - Medium Sign-in Risks'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Working on Conditional Access Policy 'EntraBlog POC - 050 - GLOBAL - ALLOW - Medium Sign-in Risks'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Conditional Access Policy 'EntraBlog POC - 050 - GLOBAL - ALLOW - Medium Sign-in Risks' in 'Report-Only' mode created.
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Checking if group 'EntraBlog POC - CA Exclude - 055 - GLOBAL - ALLOW - Medium User Risks' exists in tenant..
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Creating new group 'EntraBlog POC - CA Exclude - 055 - GLOBAL - ALLOW - Medium User Risks'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Working on Conditional Access Policy 'EntraBlog POC - 055 - GLOBAL - ALLOW - Medium User Risks'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Conditional Access Policy 'EntraBlog POC - 055 - GLOBAL - ALLOW - Medium User Risks' in 'Report-Only' mode created.
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Checking if group 'EntraBlog POC - CA Exclude - 060 - GLOBAL - ALLOW - Admins with PR MFA' exists in tenant..
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Creating new group 'EntraBlog POC - CA Exclude - 060 - GLOBAL - ALLOW - Admins with PR MFA'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Working on Conditional Access Policy 'EntraBlog POC - 060 - GLOBAL - ALLOW - Admins with PR MFA'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Conditional Access Policy 'EntraBlog POC - 060 - GLOBAL - ALLOW - Admins with PR MFA' in 'Report-Only' mode created.
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Checking if group 'EntraBlog POC - CA Exclude - 065 - GLOBAL - ALLOW - Mobile apps and desktop clients' exists in tenant..
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Creating new group 'EntraBlog POC - CA Exclude - 065 - GLOBAL - ALLOW - Mobile apps and desktop clients'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Working on Conditional Access Policy 'EntraBlog POC - 065 - GLOBAL - ALLOW - Mobile apps and desktop clients'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Conditional Access Policy 'EntraBlog POC - 065 - GLOBAL - ALLOW - Mobile apps and desktop clients' in 'Report-Only' mode created.
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Checking if group 'EntraBlog POC - CA Exclude - 070 - GLOBAL - ALLOW - Users with MFA' exists in tenant..
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Creating new group 'EntraBlog POC - CA Exclude - 070 - GLOBAL - ALLOW - Users with MFA'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Working on Conditional Access Policy 'EntraBlog POC - 070 - GLOBAL - ALLOW - Users with MFA'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Conditional Access Policy 'EntraBlog POC - 070 - GLOBAL - ALLOW - Users with MFA' in 'Report-Only' mode created.
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Checking if group 'EntraBlog POC - CA Exclude - 100 - GLOBAL - CONTROL - Sign-In Frequency for Admins' exists in tenant..
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Creating new group 'EntraBlog POC - CA Exclude - 100 - GLOBAL - CONTROL - Sign-In Frequency for Admins'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Working on Conditional Access Policy 'EntraBlog POC - 100 - GLOBAL - CONTROL - Sign-In Frequency for Admins'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Conditional Access Policy 'EntraBlog POC - 100 - GLOBAL - CONTROL - Sign-In Frequency for Admins' in 'Report-Only' mode created.
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Checking if group 'EntraBlog POC - CA Exclude - 105 - GLOBAL - CONTROL - Sign-In Frequency for Users' exists in tenant..
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Creating new group 'EntraBlog POC - CA Exclude - 105 - GLOBAL - CONTROL - Sign-In Frequency for Users'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Working on Conditional Access Policy 'EntraBlog POC - 105 - GLOBAL - CONTROL - Sign-In Frequency for Users'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Conditional Access Policy 'EntraBlog POC - 105 - GLOBAL - CONTROL - Sign-In Frequency for Users' in 'Report-Only' mode created.
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Checking if group 'EntraBlog POC - CA Exclude - 110 - GLOBAL - CONTROL - BYOD devices' exists in tenant..
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Creating new group 'EntraBlog POC - CA Exclude - 110 - GLOBAL - CONTROL - BYOD devices'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Working on Conditional Access Policy 'EntraBlog POC - 110 - GLOBAL - CONTROL - BYOD devices'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Conditional Access Policy 'EntraBlog POC - 110 - GLOBAL - CONTROL - BYOD devices' in 'Report-Only' mode created.
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Checking if group 'EntraBlog POC - CA Exclude - 115 - GLOBAL - CONTROL - Register security information' exists in tenant..
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Creating new group 'EntraBlog POC - CA Exclude - 115 - GLOBAL - CONTROL - Register security information'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Working on Conditional Access Policy 'EntraBlog POC - 115 - GLOBAL - CONTROL - Register security information'
[New-EntraIDConditionalAccessPolicyFromJson.ps1] : Conditional Access Policy 'EntraBlog POC - 115 - GLOBAL - CONTROL - Register security information' in 'Report-Only' mode created.

EnableLogs Prefix
---------- ------
True       EntraBlog POC
Transcript stopped, output file is /formula5/CaaC/Logs/New-EntraIDConditionalAccessPolicyFromJson_2025_01-24_13_52_25.log
```
