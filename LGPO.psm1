Function Set-SystemSetting {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    Param (

    [Parameter(Mandatory=$true,Position=0)]
    [Alias("Path")]
    [string]$RegPath,

    [Parameter(Mandatory=$false,Position=1)]
    [Alias("v")]
    [string]$Name,

    [Parameter(Mandatory=$false,Position=2)]
    [Alias("d")]
    $Value,

    [Parameter(Mandatory=$false,Position=3)]
    [ValidateSet('None','String','Binary','DWord','ExpandString','MultiString','QWord')]
    [Alias("PropertyType","t")]
    $Type,

    [Parameter(Mandatory=$false,Position=4)]
    [Alias("f")]
    [switch]$Force,

    [Parameter(Mandatory=$false)]
    [boolean]$TryLGPO,

    [Parameter(Mandatory=$false)]
    $LGPOBinaryPath,

    [Parameter(Mandatory=$false)]
    [string]$LogPath,

    [Parameter(Mandatory=$false)]
    [switch]$RemoveFile

    )
    Begin
    {
        ## Get the name of this function
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference')
        }

        if (-not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = $PSCmdlet.SessionState.PSVariable.GetValue('ConfirmPreference')
        }
        if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
            $WhatIfPreference = $PSCmdlet.SessionState.PSVariable.GetValue('WhatIfPreference')
        }

    }
    Process
    {
        $RegKeyHive = ($RegPath).Split('\')[0].Replace('Registry::','').Replace(':','')

        #if Name not specified, grab last value from full path
        If(!$Name){
            $RegKeyPath = Split-Path ($RegPath).Split('\',2)[1] -Parent
            $RegKeyName = Split-Path ($RegPath).Split('\',2)[1] -Leaf
        }
        Else{
            $RegKeyPath = ($RegPath).Split('\',2)[1]
            $RegKeyName = $Name
        }

        #The -split operator supports specifying the maximum number of sub-strings to return.
        #Some values may have additional commas in them that we don't want to split (eg. LegalNoticeText)
        [String]$Value = $Value -split ',',2

        Switch($RegKeyHive){
            HKEY_LOCAL_MACHINE {$LGPOHive = 'Computer';$RegHive = 'HKLM:'}
            MACHINE {$LGPOHive = 'Computer';$RegHive = 'HKLM:'}
            HKLM {$LGPOHive = 'Computer';$RegHive = 'HKLM:'}
            HKEY_CURRENT_USER {$LGPOHive = 'User';$RegHive = 'HKCU:'}
            HKEY_USERS {$LGPOHive = 'User';$RegHive = 'Registry::HKEY_USERS'}
            HKCU {$LGPOHive = 'User';$RegHive = 'HKCU:'}
            HKU {$LGPOHive = 'User';$RegHive = 'Registry::HKEY_USERS'}
            USER {$LGPOHive = 'User';$RegHive = 'HKCU:'}
            default {$LGPOHive = 'Computer';$RegHive = 'HKLM:'}
        }

        #convert registry type to LGPO type
        Switch($Type){
            'None' {$LGPORegType = 'NONE'}
            'String' {$LGPORegType = 'SZ'}
            'ExpandString' {$LGPORegType = 'EXPAND_SZ'}
            'Binary' {$LGPORegType = 'BINARY'; $value = Convert-ToHexString $value}
            'DWord' {$LGPORegType = 'DWORD'}
            'QWord' {$LGPORegType = 'DWORD_BIG_ENDIAN'}
            'MultiString' {$LGPORegType = 'LINK'}
            default {$LGPORegType = 'DWORD';$Type = 'DWord'}
        }

        Try{
            #check if tryLGPO is set and path is set
            If($TryLGPO -and $LGPOBinaryPath)
            {
                #does LGPO path exist?
                If(Test-Path $LGPOBinaryPath)
                {
                    #$lgpoout = $null
                    $lgpoout = "; ----------------------------------------------------------------------`r`n"
                    $lgpoout += "; PROCESSING POLICY`r`n"
                    $lgpoout += "; Source file:`r`n"
                    $lgpoout += "`r`n"
                    
                    # build a unique output file
                    $LGPOfile = ($RegKeyHive + '-' + $RegKeyPath.replace('\','-').replace(' ','') + '-' + $RegKeyName.replace(' ','') + '.lgpo')
                    
                    #Remove the Username or SID from Registry key path
                    If($LGPOHive -eq 'User'){
                        $UserID = $RegKeyPath.Split('\')[0]
                        If($UserID -match "DEFAULT|S-1-5-21-(\d+-?){4}$"){
                            $RegKeyPath = $RegKeyPath.Replace($UserID+"\","")
                        }
                    }
                    #complete LGPO file
                    Write-Verbose ("LGPO applying [{3}] to registry: [{0}\{1}\{2}] as a Group Policy item" -f $RegHive,$RegKeyPath,$RegKeyName,$RegKeyName)
                    $lgpoout += "$LGPOHive`r`n"
                    $lgpoout += "$RegKeyPath`r`n"
                    $lgpoout += "$RegKeyName`r`n"
                    $lgpoout += "$($LGPORegType):$Value`r`n"
                    $lgpoout += "`r`n"
                    $lgpoout | Out-File "$env:Temp\$LGPOfile"

                    If($VerbosePreference){$args = "/v /q /t"}Else{$args="/q /t"}
                    Write-Verbose "Start-Process $LGPOBinaryPath -ArgumentList '/t $env:Temp\$LGPOfile' -RedirectStandardError '$env:Temp\$LGPOfile.stderr.log'"
                    
                    If(!$WhatIfPreference){$result = Start-Process $LGPOBinaryPath -ArgumentList "$args $env:Temp\$LGPOfile /v" -RedirectStandardError "$env:Temp\$LGPOfile.stderr.log" -Wait -NoNewWindow -PassThru | Out-Null}
                    Write-Verbose ("LGPO ran successfully. Exit code: {0}" -f $result.ExitCode)
                }
                Else{
                    Write-Verbose ("LGPO will not be used. Path not found: {0}" -f $LGPOBinaryPath)

                }
            }
            Else{
                Write-Verbose ("LGPO not enabled. Hardcoding registry keys [{0}\{1}\{2}]" -f $RegHive,$RegKeyPath,$RegKeyName)
            }
        }
        Catch{
            If($TryLGPO -and $LGPOBinaryPath){
                Write-Error ("LGPO failed to run. exit code: {0}. Hardcoding registry keys [{1}\{2}\{3}]" -f $result.ExitCode,$RegHive,$RegKeyPath,$RegKeyName)
            }
        }
        Finally
        {
            #wait for LGPO file to finish generating
            start-sleep 1
            
            #verify the registry value has been set
            Try{
                If( -not(Test-Path ($RegHive +'\'+ $RegKeyPath)) ){
                    Write-Verbose ("Path was not found; Creating path and setting registry keys [{0}\{1}] with value [{2}]" -f ($RegHive +'\'+ $RegKeyPath),$RegKeyName,$Value)
                    #New-Item -Path ($RegHive +'\'+ $RegKeyPath) -Force -WhatIf:$WhatIfPreference -ErrorAction Stop | Out-Null
                    New-Item ($RegHive +'\'+ $RegKeyPath) -Force:$Force -WhatIf:$WhatIfPreference -ErrorAction Stop | New-ItemProperty -Name $RegKeyName -PropertyType $Type -Value $Value -Force:$Force -ErrorAction Stop | Out-Null
                    #wait for registry path to popluate (only on slower systems)
                    #start-sleep 2
                    #New-ItemProperty -Path ($RegHive +'\'+ $RegKeyPath) -Name $RegKeyName -PropertyType $Type -Value $Value -Force:$Force -WhatIf:$WhatIfPreference -ErrorAction Stop | Out-Null
                } 
                Else{
                    Write-Verbose ("Setting key name [{1}] at path [{0}] with value [{2}]" -f ($RegHive +'\'+ $RegKeyPath),$RegKeyName,$Value)
                    Set-ItemProperty -Path ($RegHive +'\'+ $RegKeyPath) -Name $RegKeyName -Value $Value -Force:$Force -WhatIf:$WhatIfPreference -ErrorAction Stop | Out-Null
                }
            }
            Catch{
                Write-Error ("Unable to configure registry key [{0}\{1}\{2}]. {4}" -f $RegHive,$RegKeyPath,$RegKeyName,$Value,$_.Exception.Message)
            }

        }
    }
    End {
        #cleanup LGPO logs
        If(!$WhatIfPreference){$RemoveFile =  $false}

        If($LGPOfile -and (Test-Path "$env:Temp\$LGPOfile") -and $RemoveFile){
               Remove-Item "$env:Temp\$LGPOfile" -ErrorAction SilentlyContinue | Out-Null
               #Remove-Item "$env:Temp" -Include "$LGPOfile*" -Recurse -Force
        }
    }

}


Function Set-UserSetting {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    Param (
        [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [Alias("Path")]
        [string]$RegPath,

        [Parameter(Mandatory=$false,Position=1)]
        [Alias("v")]
        [string]$Name,

        [Parameter(Mandatory=$false,Position=2)]
        [Alias("d")]
        $Value,

        [Parameter(Mandatory=$false,Position=3)]
        [ValidateSet('None','String','Binary','DWord','ExpandString','MultiString','QWord')]
        [Alias("PropertyType","t")]
        [string]$Type,

        [Parameter(Mandatory=$false,Position=4)]
        [ValidateSet('CurrentUser','AllUsers','DefaultUser')]
        [Alias("Users")]
        [string]$ApplyTo = $Global:ApplyToProfiles,


        [Parameter(Mandatory=$false,Position=5)]
        [Alias("r")]
        [switch]$Remove,

        [Parameter(Mandatory=$false,Position=6)]
        [Alias("f")]
        [switch]$Force,

        [Parameter(Mandatory=$false)]
        [boolean]$TryLGPO,

        [Parameter(Mandatory=$false)]
        $LGPOBinaryPath,

        [Parameter(Mandatory=$false)]
        [string]$LogPath

    )
    Begin
    {
        ## Get the name of this function
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference')
        }

        if (-not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = $PSCmdlet.SessionState.PSVariable.GetValue('ConfirmPreference')
        }
        if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
            $WhatIfPreference = $PSCmdlet.SessionState.PSVariable.GetValue('WhatIfPreference')
        }

        #If user profile variable doesn't exist, build one
        If(!$Global:UserProfiles){
            # Get each user profile SID and Path to the profile
            $AllProfiles = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*" | Where-Object {$_.PSChildName -match "S-1-5-21-(\d+-?){4}$" } | 
                    Select-Object @{Name="SID"; Expression={$_.PSChildName}}, @{Name="UserHive";Expression={"$($_.ProfileImagePath)\NTuser.dat"}}, @{Name="UserName";Expression={Split-Path $_.ProfileImagePath -Leaf}}

            # Add in the DEFAULT User Profile (Not be confused with .DEFAULT)
            $DefaultProfile = "" | Select-Object SID, UserHive,UserName
            $DefaultProfile.SID = "DEFAULT"
            $DefaultProfile.Userhive = "$env:systemdrive\Users\Default\NTuser.dat"
            $DefaultProfile.UserName = "Default"

            #Add it to the UserProfile list
            $Global:UserProfiles = @()
            $Global:UserProfiles += $AllProfiles
            $Global:UserProfiles += $DefaultProfile

            #get current users sid
            [string]$CurrentSID = (Get-WmiObject win32_useraccount | Where-Object {$_.name -eq $env:username}).SID
        }
    }
    Process
    { 
        #grab the hive from the regpath
        $RegKeyHive = ($RegPath).Split('\')[0].Replace('Registry::','').Replace(':','')
        
        #Grab user keys and profiles based on whom it will be applied to
        Switch($ApplyTo){
            'AllUsers'      {$RegHive = 'HKEY_USERS'; $ProfileList = $Global:UserProfiles}
            'CurrentUser'   {$RegHive = 'HKCU'      ; $ProfileList = ($Global:UserProfiles | Where-Object{$_.SID -eq $CurrentSID})}
            'DefaultUser'   {$RegHive = 'HKU'       ; $ProfileList = $DefaultProfile}
            default         {$RegHive = $RegKeyHive ; $ProfileList = ($Global:UserProfiles | Where-Object{$_.SID -eq $CurrentSID})}
        }
        
        #check if hive is local machine.
        If($RegKeyHive -match "HKEY_LOCAL_MACHINE|HKLM|HKCR"){
            Write-Verbose ("Registry path [{0}] is not a user path. Use Set-SystemSetting cmdlet instead" -f $RegKeyHive)
            return
        }
        #check if hive was found and is a user hive
        ElseIf($RegKeyHive -match "HKEY_USERS|HKEY_CURRENT_USER|HKCU|HKU"){
            #if Name not specified, grab last value from full path
             If(!$Name){
                 $RegKeyPath = Split-Path ($RegPath).Split('\',2)[1] -Parent
                 $RegKeyName = Split-Path ($RegPath).Split('\',2)[1] -Leaf
             }
             Else{
                 $RegKeyPath = ($RegPath).Split('\',2)[1]
                 $RegKeyName = $Name
             } 
        }
        ElseIf($ApplyTo){
            #if Name not specified, grab last value from full path
            If(!$Name){
                $RegKeyPath = Split-Path ($RegPath) -Parent
                $RegKeyName = Split-Path ($RegPath) -Leaf
            }
            Else{
                $RegKeyPath = $RegPath
                $RegKeyName = $Name
            } 
        }
        Else{
            Write-Verbose ("User registry hive was not found or specified in Keypath [{0}]. Either use the -ApplyTo Switch or specify user hive [eg. HKCU\]" -f $RegPath)
            return
        }
  
        #loope through profiles as long as the hive is not the current user hive
        If($RegHive -notmatch 'HKCU|HKEY_CURRENT_USER'){

            $p = 1
            # Loop through each profile on the machine
            Foreach ($UserProfile in $ProfileList) {
                
                Try{
                    $objSID = New-Object System.Security.Principal.SecurityIdentifier($UserProfile.SID)
                    $UserName = $objSID.Translate([System.Security.Principal.NTAccount]) 
                }
                Catch{
                    $UserName = $UserProfile.UserName
                }

                #loadhive if not mounted
                If (($HiveLoaded = Test-Path Registry::HKEY_USERS\$($UserProfile.SID)) -eq $false) {
                    Start-Process -FilePath "CMD.EXE" -ArgumentList "/C REG.EXE LOAD HKU\$($UserProfile.SID) $($UserProfile.UserHive)" -Wait -WindowStyle Hidden
                    $HiveLoaded = $true
                }

                If ($HiveLoaded -eq $true) {   
                    If($Message){Write-Verbose ("{0} for User [{1}]" -f $Message,$UserName)}
                    If($Remove){
                        Remove-ItemProperty "$RegHive\$($UserProfile.SID)\$RegKeyPath" -Name $RegKeyName -Force:$Force -WhatIf:$WhatIfPreference -ErrorAction SilentlyContinue | Out-Null  
                    }
                    Else{
                        Set-SystemSetting -Path "$RegHive\$($UserProfile.SID)\$RegKeyPath" -Name $RegKeyName -Type $Type -Value $Value -Force:$Force -WhatIf:$WhatIfPreference -TryLGPO:$TryLGPO
                    }
                }

                #remove any leftover reg process and then remove hive
                If ($HiveLoaded -eq $true) {
                    [gc]::Collect()
                    Start-Sleep -Seconds 3
                    Start-Process -FilePath "CMD.EXE" -ArgumentList "/C REG.EXE UNLOAD HKU\$($UserProfile.SID)" -Wait -PassThru -WindowStyle Hidden | Out-Null
                }
                $p++
            }
        }
        Else{
            
            If($Remove){
                Remove-ItemProperty "$RegHive\$RegKeyPath\$RegKeyPath" -Name $RegKeyName -Force:$Force -WhatIf:$WhatIfPreference -ErrorAction SilentlyContinue | Out-Null  
            }
            Else{
                Set-SystemSetting -Path "$RegHive\$RegKeyPath" -Name $RegKeyName -Type $Type -Value $Value -Force:$Force -WhatIf:$WhatIfPreference -TryLGPO:$TryLGPO
            }
        }

    }
    End {

    }
}