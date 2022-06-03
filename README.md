# LGPO PowerShell module

A module that will apply registry keys using LGPO instead.

## Prerequisites

The module does look in the folder c:\ProgramData\LGPO for the LGPO.exe binary.
The LGPO binaries from Microsoft Security Compliance Toolkit 1.0 will be needed. You can get it from here 'https://www.microsoft.com/en-us/download/details.aspx?id=55319'

## Cmdlets
- Get-LocalPolicySystemSettings - Retrieves all system policies
- Set-LocalPolicySetting - Attempts to apply local system policy from a registry key
- Update-LocalPolicySettings - Attempts to update local system policy from a file or data
- Remove-LocalPolicySetting - Attempts to remove local system policy.
- Get-LocalPolicyUserSettings - Retrieves all user policies
- Set-LocalPolicyUserSetting - Defaults to all users. Applies policy to all users
- Remove-LocalPolicyUserSetting - Defaults to all users. removes policy setting for all users

## Install

 - Option 1: Run the provided **Install-LGPO.ps1**

 - Option 2: Manually download LGPO bits from 'https://www.microsoft.com/en-us/download/details.aspx?id=55319', copy LGPO.exe to _C:\ProgramData\LGPO_, then install module using commands:

```powershell
Install-Module LGPO -Force
Import-Module LGPO
```

## Examples

```powershell
#gets current policies of system as object
Get-LocalPolicySystemSettings

#gets current policies of users as object
Get-LocalPolicyUserSettings

#Sets policy name to system
Set-LocalPolicySetting -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ImmersiveShell' -Name 'UseActionCenterExperience' -Type DWord -Value 0

#Removed system policy by name (sets to not configured)
Remove-LocalPolicySetting -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ImmersiveShell' -Name 'UseActionCenterExperience'

#Removed system policy by name but ensure it can be set back (set to not configured but also enforces the key from being recreated)
Remove-LocalPolicySetting -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ImmersiveShell' -Name 'UseActionCenterExperience' -Enforce

#Sets policy name to users
Set-LocalPolicyUserSetting -RegPath 'HCKU:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'DisableNotificationCenter' -Type DWord -Value 1

#Remove policy name for users with verbose output
Remove-LocalPolicyUserSetting -RegPath 'HCKU:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'DisableNotificationCenter' -Verbose

# Update (replace) policy from lpo generated txt file
Update-LocalPolicySettings -Policy Computer -LgpoFile C:\Lgpo.txt

# Filter out policies with * and rebuild
(Get-LocalPolicySystemSettings -Filter '$_.Name -ne "*"') | Update-LocalPolicySettings -Policy Computer
```

## Validate

Run _gpresult /H report.html_ to see the local policies that are set.

- If key set by LGPO do not exist as an Administrative template, they will be set in Extra Registry Settings

- You can also use _gpedit.msc_ to view settings set in Administrative template only
