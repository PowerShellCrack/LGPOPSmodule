
#=======================================================
# MAIN
#=======================================================
Import-Module LGPO

# Set Outlook's Cached Exchange Mode behavior
Write-Host ("Set user policy for Outlook's Cached Exchange Mode behavior")
Set-LocalPolicyUserSetting -RegPath 'HKCU:\software\policies\microsoft\office\16.0\outlook\cached mode' -Name Enable -Type DWord -Value 1
Set-LocalPolicyUserSetting -RegPath 'HKCU:\software\policies\microsoft\office\16.0\outlook\cached mode' -Name SyncWindowSetting -Type DWord -Value 1
Set-LocalPolicyUserSetting -RegPath 'HKCU:\software\policies\microsoft\office\16.0\outlook\cached mode' -Name CalendarSyncWindowSetting -Type DWord -Value 1
Set-LocalPolicyUserSetting -RegPath 'HKCU:\software\policies\microsoft\office\16.0\outlook\cached mode' -Name CalendarSyncWindowSettingMonths -Type DWord -Value 1

# Set the Office Update UI behavior.
Write-Host ("Set the Office Update UI behavior")
Set-LocalPolicySetting -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common\officeupdate' -Name HideUpdateNotifications -Type DWord -Value 1
Set-LocalPolicySetting -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common\officeupdate' -Name HideEnableDisableUpdates -Type DWord -Value 1

#Cleanup and Complete
Write-Host ('Completed Office 365 install')

#Get GP report
$ReportFile = ("gpresult_" + $env:ComputerName + ".html")
$InstallArguments = "/H $env:Temp\$ReportFile /F"
Remove-Item $env:Temp -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
Write-Host ('Running Command: Start-Process -FilePath "GPRESULT" -ArgumentList "{0}" -Wait -Passthru' -f $InstallArguments)
$Result = Start-Process -FilePath GPRESULT -ArgumentList $InstallArguments -RedirectStandardError "$env:temp\gpresult_error.txt" -RedirectStandardOutput "$env:temp\gpresult_stdout.txt"  -Wait -Passthru -NoNewWindow

#Launch file in edge
If($Result.ExitCode -eq 0){
    start shell:AppsFolder\Microsoft.MicrosoftEdge_8wekyb3d8bbwe!MicrosoftEdge "$env:Temp\$ReportFile"
}
Else{
    $errormsg = Get-Content "$env:temp\gpresult_error.txt" -Raw -ErrorAction SilentlyContinue
    Write-Host ('Failed to create file [{0}], error code: {1}, {2}'  -f "$env:Temp\$ReportFile",$Result.ExitCode,$errormsg) -ForegroundColor Red
}
