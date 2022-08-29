# LGPO PowerShell module

A powershell module that applies registry keys using the [Microsoft LGPO Toolkit](https://www.microsoft.com/en-us/download/details.aspx?id=55319).

## Prerequisites

The module requires the LGPO.exe binary to be located in `C:\ProgramData\LGPO\`
The LGPO binaries from Microsoft Security Compliance Toolkit 1.0 will be needed. You can get it from here 'https://www.microsoft.com/en-us/download/details.aspx?id=55319'

## Cmdlets
- Get-LocalPolicySystemSettings - Retrieves all system policies
- Set-LocalPolicySetting - Attempts to apply local system policy from a registry key
- Update-LocalPolicySettings - Attempts to update local system policy from a file or data
- Remove-LocalPolicySetting - Attempts to remove local system policy
- Get-LocalPolicyUserSettings - Retrieves all user policies
- Set-LocalPolicyUserSetting - Attempts to apply local user policy (Defaults to all users)
- Remove-LocalPolicyUserSetting - Attempts to remove local user policy (Defaults to all users)
- Clear-LocalPolicySetting - Erases all policies from system (Defaults to all polices)

## Install

 - Option 1: Run the provided **Install-LGPO.ps1**

 - Option 2: Manually download LGPO bits from 'https://www.microsoft.com/en-us/download/details.aspx?id=55319', copy LGPO.exe to _C:\ProgramData\LGPO_, then install module using the following commands:

    ```powershell
    Install-Module LGPO -Force
    Import-Module LGPO
    ```

## Examples

```powershell
# Gets current policies of system as object
Get-LocalPolicySystemSettings

# Gets current policies of users as object
Get-LocalPolicyUserSettings

# Sets policy name to system
Set-LocalPolicySetting -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ImmersiveShell' -Name 'UseActionCenterExperience' -Type DWord -Value 0

# Remove system policy by name (sets to not configured)
Remove-LocalPolicySetting -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ImmersiveShell' -Name 'UseActionCenterExperience'

# Remove system policy by name but ensure it can be set back (set to not configured but also enforces the key from being recreated)
Remove-LocalPolicySetting -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ImmersiveShell' -Name 'UseActionCenterExperience' -Enforce

# Sets policy name to users
Set-LocalPolicyUserSetting -RegPath 'HCKU:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'DisableNotificationCenter' -Type DWord -Value 1

# Remove policy name for users with verbose output
Remove-LocalPolicyUserSetting -RegPath 'HCKU:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'DisableNotificationCenter' -Verbose

# Update (replace) policy from lpo generated txt file
Update-LocalPolicySettings -Policy Computer -LgpoFile C:\Lgpo.txt

# Filter out policies with * and rebuild
(Get-LocalPolicySystemSettings -Filter '$_.Name -ne "*"') | Update-LocalPolicySettings -Policy Computer

# Clear all policies with confirmation
Clear-LocalPolicySetting

# Clear computer policies without confirmation
Clear-LocalPolicySetting -Policy Computer -Confirm:$False

```

## Validate

Run _gpresult /H report.html_ to see the local policies that are set.

- If keys set by LGPO do not exist as an Administrative template, they will be set in Extra Registry Settings

- You can also use _gpedit.msc_ to view settings set in Administrative template only
