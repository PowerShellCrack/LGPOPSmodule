# LGPO PowerShell module

A module that will apply registry keys using LGPO instead.

- Now published to the [PowerShell Gallery](https://www.powershellgallery.com/packages/LGPO/1.0.1)
## Prerequisites

The module does look in the folder c:\ProgramData\LGPO for the LGPO.exe binary.
The LGPO binaries from Microsoft Security Compliance Toolkit 1.0 will be needed.

You can get it from here 'https://www.microsoft.com/en-us/download/details.aspx?id=55319'

## Cmdlets

 - Set-LocalPolicySetting - Attempts to apply local security policy.
 - Remove-LocalPolicySetting - Attempts to remove local security policy.
 - Set-LocalPolicyUserSetting - Defaults to all users. Applies policy to all users
 - Remove-LocalPolicyUserSetting - Defaults to all users. removes policy setting for all users

## Updates

- SEE [CHANGELOG.MD](.\CHANGELOG.MD)

### NOTE: If installed this module before, be sure to run __Uninstall-Module LGPO -AllVersions__ to ensure to uninstall older versions. _The module cmdlets have changed_

## Install

__Install-Module -Name LGPO__

## Examples

```powershell
Set-LocalPolicySetting -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ImmersiveShell' -Name 'UseActionCenterExperience' -Type DWord -Value 0

Remove-LocalPolicySetting -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ImmersiveShell' -Name 'UseActionCenterExperience'

Set-LocalPolicyUserSetting -RegPath 'SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'DisableNotificationCenter' -Type DWord -Value 1

Remove-LocalPolicyUserSetting -RegPath 'SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'DisableNotificationCenter' -Verbose
```

## Validate

Run _gpresult /H report.html_ to see the local policies that are set.

- If key set by LGPO do not exist as an Administrative template, they will be set in Extra Registry Settings

- You can also use _gpedit.msc_ to view settings set in Administrative template only
