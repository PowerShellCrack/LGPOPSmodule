
#=======================================================
# MAIN
#=======================================================
#Import-Module LGPO

# Set Outlook's Cached Exchange Mode behavior
Write-Host ("Removing user policy for Outlook's Cached Exchange Mode behavior")
Remove-LocalPolicyUserSetting -RegPath 'HKCU:\software\policies\microsoft\office\16.0\outlook\cached mode' -Name Enable -EnForce
Remove-LocalPolicyUserSetting -RegPath 'HKCU:\software\policies\microsoft\office\16.0\outlook\cached mode' -Name SyncWindowSetting -EnForce
Remove-LocalPolicyUserSetting -RegPath 'HKCU:\software\policies\microsoft\office\16.0\outlook\cached mode' -Name CalendarSyncWindowSetting -EnForce
Remove-LocalPolicyUserSetting -RegPath 'HKCU:\software\policies\microsoft\office\16.0\outlook\cached mode' -Name CalendarSyncWindowSettingMonths -EnForce

# Set the Office Update UI behavior.
Write-Host ("Removing system policy from Office Update UI behavior")
Remove-LocalPolicySetting -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common\officeupdate' -Name HideUpdateNotifications -EnForce
Remove-LocalPolicySetting -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common\officeupdate' -Name HideEnableDisableUpdates -EnForce

#Cleanup and Complete
Write-Host ('Completed policy configuration')

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
