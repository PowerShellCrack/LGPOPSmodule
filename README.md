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
 - Set-LocalUserPolicySetting - Defaults to all users. Applies policy to all users
 - Remove-LocalUserPolicySetting - Defaults to all users. removes policy setting for all users

## Install

Install-Module -Name LGPO

## Examples

```powershell
Set-LocalPolicySetting -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ImmersiveShell' -Name 'UseActionCenterExperience' -Type DWord -Value 0

Remove-LocalPolicySetting -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ImmersiveShell' -Name 'UseActionCenterExperience'

Set-LocalUserPolicySetting -RegPath 'SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'DisableNotificationCenter' -Type DWord -Value 1

Remove-LocalUserPolicySetting -RegPath 'SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'DisableNotificationCenter' -Verbose
```

## Validate

Run _gpresult /H report.html_ to see the local policies that are set.

- If key set by LGPO do not exist as an Administrative template, they will be set in Extra Registry Settings

- You can also use _gpedit.msc_ to view settings set in Administrative template only
