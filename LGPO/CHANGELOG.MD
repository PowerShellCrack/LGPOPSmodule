# Change log for LGPO module

## 1.0.3.3 June 03, 2022

- Fixed force registry parameter for Set-LocalPolicySetting; missing colon for registry hive path on (eg.HKLM:)
- Fixed pathing issue for LGPO registry keys; missing variable creation in if statement during SID check
- Added Clear-LocalPolicySettings; always to clear all machine or use policies

## 1.0.3.2 June 02, 2022

- Changed NoNewWindow to WindowStyle Hidden; hides LGPO popup
- Fixed user policy cmdlet; unable to use force beacuse of key pathing issues

## 1.0.3.1 May 26, 2022

- Fixed Remove-LocalPolicySetting cmdlet; changed force parameter to Enforce
- Change error output with Write-Error; cleaned up output
- Added Machine to policy parameter to support calls to policy for local system
- Fixed Remove-LocalPolicyUserSetting cmdlet; ensured if no name is specified it remvoed all values for path

## 1.0.3.0 May 14, 2022

- Changed cmdlet to LocalPolicyUserSetting; follows module names and mitigates existing module conflicts
- Changed all argument lists to array; support dynamic changes such as verbose output
- Added get cmdlets; provides export of system and user policies
- Changed function of Remove cmdlets; defaults to remove settings without enforcement.

## 1.0.2.5 May 13, 2022

- Fixed Remove local settings for all values parameter
- Added debugging to cmdlets; leave working files in temp directory.
- renamed working files to reflect cmdlet running; provides better troubleshooting
- Changed Set and remove to force Name parameter; also fixed default parameters calls

## 1.0.2.4 May 12, 2022

- Fixed ExpandString for LGPO.
- Added delete all for LGPO
- Removed Qword from type option, not used in LGPO.

## 1.0.2.2 Mar 08, 2022

- Updated psd1; added root module and functions to export; foxes exported commands
- Updated versioning to meet 4 integer requirements
- Fixed pms1 to psm1 to call right file
- Changed user cmdlets to \<action\>-LocalPolicyUserSetting; standardized policy cmdlets

## 1.0.1 Feb 26, 2022

- Renamed modules to be more accurate.
- Preset LGPO binary path to C:\Programdata\LGPO; can be modified if needed
- Changed $args to $lgpoargs; ensure it doesn't conflict with built in variable

## 1.0.0 April 29,2020

- Initial upload; Never tested.
