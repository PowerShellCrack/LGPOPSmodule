# Change log for LGPO module

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
