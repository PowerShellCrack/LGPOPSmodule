# LGPOPSmodule
A module apply registry keys using LGPO instead

## Functions 
 - Set-SystemSetting - Atttempts to apply registry settings via local security policy. 
 - Set-UserSetting - Default to all users. Applies registry key settings via hive


## LGPO
  You must have LGPO located somewhere. The funtions will call for it. If not found, it will default to using registry keys
