# Change log for LGPO module

## 1.0.3.9 April 22, 2023

- Fixed Machine and Computer check in two cmdlets. Thanks @simonlrostron
- Fixed LGPO installer. Space after file name causing hang. Thanks [@jonblankenship] (https://github.com/jonblankenship)
- Fixed Posh code lint problems. 

## 1.0.3.8 September 1, 2022

- Fixed enforce cmdlet Set-LocalPolicySetting; was set to $force
- Added gpupdate to each cmdlet when calling Enforce

## 1.0.3.7 August 29, 2022

- Fixed enforce Boolean value; made alias for Force for compatibility
- Added pipeline for Key Name (Path and value must be same)

## 1.0.3.6 August 29, 2022

- Fixed name not found for Set-LocalUserPolicySetting; Apply to wasn't writing correct path and name
- Removed test sample data from module.

## 1.0.3.5 August 29, 2022

- Fixed issue where running Set-LocalPolicyUserSetting with HKLM in path still applies to user. Should error with message
- Changed some write-error to throw to ensure terminating; updated string to create new line for download link
- Updated Get-LocalPolicySettings to look for lgpo path as default instead of forced
- Grammatical updates. Thanks [@meichthys](https://github.com/meichthys)

## 1.0.3.4 June 05, 2022

- updated position parameter from 0 to 1; mistake on listed as first parameter
- updated module tags to reflect usage and search in gallery

## 1.0.3.3 June 03, 2022

- Fixed force registry parameter for Set-LocalPolicySetting; missing colon for registry hive path on (eg.HKLM:)
- Fixed pathing issue for LGPO registry keys; missing variable creation in if statement during SID check
- Added Clear-LocalPolicySettings; always to clear all machine or use policies

## 1.0.3.2 June 02, 2022

- Changed NoNewWindow to WindowStyle Hidden; hides LGPO popup
- Fixed user policy cmdlet; unable to use force because of key pathing issues

## 1.0.3.1 May 26, 2022

- Fixed Remove-LocalPolicySetting cmdlet; changed force parameter to Enforce
- Change error output with Write-Error; cleaned up output
- Added Machine to policy parameter to support calls to policy for local system
- Fixed Remove-LocalPolicyUserSetting cmdlet; ensured if no name is specified it removed all values for path

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
