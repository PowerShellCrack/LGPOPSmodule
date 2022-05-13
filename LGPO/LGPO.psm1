
### -----------------------------------
### Set-LocalPolicySetting Cmdlet
### -----------------------------------

Function Set-LocalPolicySetting {
    <#
        .SYNOPSIS
        Converts registry key into GPO

        .DESCRIPTION
        Uses LGPO tool to convert registry key into Local policy

        .NOTES
        Download LGPO from https://www.microsoft.com/en-us/download/details.aspx?id=55319
        Create a Directory in C:\ProgramData\LGPO
        Unzip LGPO.exe to that folder

        .PARAMETER RegPath
        Required. Specify path to registry item

        .PARAMETER Name
        Specify Name of registry key to set. If no name specified, RegPath will be split up to use leaf as name

        .PARAMETER Type
        Default to 'DWord'. Specify type of registry item

        .PARAMETER Value
        Specify value or Key name

        .PARAMETER Force
        If LGPO failed, this will set the registry item anyway

        .PARAMETER LGPOBinaryPath
        Defaults to "C:\ProgramData\LGPO\LGPO.exe". Download LGPO from https://www.microsoft.com/en-us/download/details.aspx?id=55319. Use this to specify alternate location

        .EXAMPLE
        Set-LocalPolicySetting -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarMn' -Type DWord -Value 0

        .EXAMPLE
        Set-LocalPolicySetting -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ImmersiveShell' -Name 'UseActionCenterExperience' -Type DWord -Value 0

        .EXAMPLE
        Set-LocalPolicySetting -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ImmersiveShell' -Name 'UseActionCenterExperience' -Type DWord -Value 0 -Verbose

        .EXAMPLE
        Set-LocalPolicySetting -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ImmersiveShell' -Name 'UseActionCenterExperience' -Type DWord -Value 0 -LGPOBinaryPath c:\lgpo\lgpo.exe
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [Alias("Path")]
        [string]$RegPath,

        [Parameter(Mandatory=$false,Position=1)]
        [Alias("v")]
        [string]$Name,

        [Parameter(Mandatory=$false,Position=2)]
        [ValidateSet('None','String','Binary','DWord','ExpandString','MultiString','QWord')]
        [Alias("PropertyType","t")]
        $Type = 'DWord',

        [Parameter(Mandatory=$True,Position=3)]
        [Alias("d")]
        $Value,

        [Parameter(Mandatory=$false)]
        [Alias("f")]
        [switch]$Force,

        [Parameter(Mandatory=$false)]
        [ValidateScript({Test-path $_ -PathType Leaf})]
        $LGPOBinaryPath = "$env:ALLUSERSPROFILE\LGPO\LGPO.exe"

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
            'String' {$LGPORegType = 'SZ';}
            'ExpandString' {$LGPORegType = 'EXSZ';}
            'Binary' {$LGPORegType = 'BINARY'; $value = (Convert-ToHexString $value)}
            'DWord' {$LGPORegType = 'DWORD'}
            'QWord' {$LGPORegType = 'DWORD_BIG_ENDIAN'}
            'MultiString' {$LGPORegType = 'MULTISZ'}
            default {$LGPORegType = 'DWORD';$Type = 'DWord'}
        }

        #rebuild full path with hive
        $RegPath = ($RegHive +'\'+ $RegKeyPath)

        #check if path is set
        If(Test-Path $LGPOBinaryPath)
        {

            #$lgpoout = $null
            $lgpoout = "; ----------------------------------------------------------------------`r`n"
            $lgpoout += "; PROCESSING POLICY`r`n"
            $lgpoout += "; Source file:`r`n"
            $lgpoout += "`r`n"

            # build a unique output file
            $LgpoFileName = ($RegKeyHive + '-' + $RegKeyPath.replace('\','-').replace(' ','') + '-' + $RegKeyName.replace(' ','') + '.lgpo')

            #Remove the Username or SID from Registry key path
            If($LGPOHive -eq 'User'){
                $UserID = $RegKeyPath.Split('\')[0]
                If($UserID -match "DEFAULT|S-1-5-21-(\d+-?){4}$"){
                    $RegKeyPath = $RegKeyPath.Replace($UserID+"\","")
                }
            }

            #complete LGPO file
            Write-Verbose ("{0} :: LGPO applying [{4}] to registry: [{1}\{2}\{3}] as a Group Policy item" -f ${CmdletName},$RegHive,$RegKeyPath,$RegKeyName,$RegKeyName)
            $lgpoout += "$LGPOHive`r`n"
            $lgpoout += "$RegKeyPath`r`n"
            $lgpoout += "$RegKeyName`r`n"
            $lgpoout += "$($LGPORegType):$Value`r`n"
            $lgpoout += "`r`n"
            $lgpoout | Out-File "$env:Temp\$LgpoFileName" -Force

            If($VerbosePreference){$lgpoargs = "/v /q /t"}Else{$lgpoargs="/q /t"}

            If($WhatIfPreference)
            {
                Write-Output ("What if: Performing the operation ""Start-Process"" on target ""{1}"" with argument ""$lgpoargs $env:Temp\$LgpoFileName /v""." -f ${CmdletName},$LGPOBinaryPath)
            }
            Else
            {
                Write-Verbose ("{0} :: Start-Process {1} -ArgumentList '/t {2}' -RedirectStandardError '{3}' -RedirectStandardOutput '{4}' -Wait -NoNewWindow -PassThru" -f ${CmdletName},$LGPOBinaryPath,"$env:Temp\$LgpoFileName","$env:Temp\$LgpoFileName.stderr","$env:Temp\$LgpoFileName.stdout")
                Try{
                    $result = Start-Process $LGPOBinaryPath -ArgumentList "$lgpoargs $env:Temp\$LgpoFileName /v" -RedirectStandardError "$env:Temp\$LgpoFileName.stderr" -RedirectStandardOutput "$env:Temp\$LgpoFileName.stdout" -Wait -NoNewWindow -PassThru -ErrorAction Stop
                    Write-Verbose ("{0} :: LGPO ran successfully." -f ${CmdletName})
                }
                Catch{
                    Write-Error ("{0} :: LGPO failed to run. {1}" -f ${CmdletName},$result.ExitCode)
                }
            }

        }
        Else{
            Write-Error ("{0} :: Local Policy was not set; LGPO binaries not found in path [{1}]. Download binaries from 'https://www.microsoft.com/en-us/download/details.aspx?id=55319' " -f ${CmdletName},$LGPOBinaryPath)
        }

        If($Force)
        {
            Write-Verbose ("{0} :: Force enabled. Hard coding registry keys [{1}\{2}\{3}]" -f ${CmdletName},$RegHive,$RegKeyPath,$RegKeyName)
            #verify the registry value has been set
            Try{
                $CurrentPos = $null
                #loop through each key path to build the correct path
                Foreach($Node in $RegPath.split('\'))
                {
                    $CurrentPos += $Node + '\'
                    New-Item $CurrentPos -ErrorAction SilentlyContinue -WhatIf:$WhatIfPreference | Out-Null
                }

                Write-Verbose ("{0} :: Setting key name [{2}] at path [{1}] with value [{3}]" -f ${CmdletName},($RegHive +'\'+ $RegKeyPath),$RegKeyName,$Value)
                Set-ItemProperty -Path $RegPath -Name $RegKeyName -Value $Value -Force:$Force -WhatIf:$WhatIfPreference -ErrorAction Stop | Out-Null
            }
            Catch{
                Write-Error ("{0} :: Unable to configure registry key [{1}\{2}\{3}]. {5}" -f ${CmdletName},$RegHive,$RegKeyPath,$RegKeyName,$Value,$_.Exception.Message)
            }
        }
    }
    End {
        #cleanup LGPO temp files
        If( (Test-Path "$env:Temp\$LgpoFileName" -PathType Leaf) -and !$WhatIfPreference){
               Remove-Item "$env:Temp\$LgpoFileName" -ErrorAction SilentlyContinue -Force | Out-Null
        }
    }

}



### -----------------------------------
### Remove-LocalPolicySetting Cmdlet
### -----------------------------------

Function Remove-LocalPolicySetting {
    <#
        .SYNOPSIS
        Removes GPO setting

        .DESCRIPTION
        Uses LGPO tool to remove local policy settings or registry key

        .NOTES
        Download LGPO from https://www.microsoft.com/en-us/download/details.aspx?id=55319
        Create a Directory in C:\ProgramData\LGPO
        Unzip LGPO.exe to that folder

        .PARAMETER RegPath
        Required. Specify path to registry item

        .PARAMETER Name
        Specify Name of registry key to remove. If no name specified, RegPath will be split up to use leaf as name

        .PARAMETER AllValues
        Ignores name and deletes all keys within path.

        .PARAMETER Force
        If LGPO failed, this will remove the registry item anyway

        .PARAMETER LGPOBinaryPath
        Defaults to "C:\ProgramData\LGPO\LGPO.exe". Download LGPO from https://www.microsoft.com/en-us/download/details.aspx?id=55319. Use this to specify alternate location

        .EXAMPLE
        Remove-LocalPolicySetting -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarMn'

        .EXAMPLE
        Remove-LocalPolicySetting -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ImmersiveShell' -Name 'UseActionCenterExperience'

        .EXAMPLE
        Remove-LocalPolicySetting -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ImmersiveShell' -Name 'UseActionCenterExperience' -Verbose

        .EXAMPLE
        Remove-LocalPolicySetting -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ImmersiveShell' -Name 'UseActionCenterExperience' -LGPOBinaryPath c:\lgpo\lgpo.exe

    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [Alias("Path")]
        [string]$RegPath,

        [Parameter(Mandatory=$false,Position=1,ParameterSetName="one")]
        [Alias("v")]
        [string]$Name,

        [Parameter(Mandatory=$false,ParameterSetName="all")]
        [Alias("a")]
        [switch]$AllValues,

        [Parameter(Mandatory=$false)]
        [Alias("f")]
        [switch]$Force,

        [Parameter(Mandatory=$false)]
        [ValidateScript({Test-path $_ -PathType Leaf})]
        $LGPOBinaryPath = "$env:ALLUSERSPROFILE\LGPO\LGPO.exe"

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

        #rebuild full path with hive
        $RegPath = ($RegHive +'\'+ $RegKeyPath)

        #check if path is set
        If(Test-Path $LGPOBinaryPath)
        {

            #$lgpoout = $null
            $lgpoout = "; ----------------------------------------------------------------------`r`n"
            $lgpoout += "; PROCESSING POLICY`r`n"
            $lgpoout += "; Source file:`r`n"
            $lgpoout += "`r`n"

            # build a unique output file
            $LgpoFileName = ($RegKeyHive + '-' + $RegKeyPath.replace('\','-').replace(' ','') + '-' + $RegKeyName.replace(' ','') + '.lgpo')

            #Remove the Username or SID from Registry key path
            If($LGPOHive -eq 'User'){
                $UserID = $RegKeyPath.Split('\')[0]
                If($UserID -match "DEFAULT|S-1-5-21-(\d+-?){4}$"){
                    $RegKeyPath = $RegKeyPath.Replace($UserID+"\","")
                }
            }

            #complete LGPO file
            Write-Verbose ("{0} :: LGPO applying [{4}] to registry: [{1}\{2}\{3}] as a Group Policy item" -f ${CmdletName},$RegHive,$RegKeyPath,$RegKeyName,$RegKeyName)
            $lgpoout += "$LGPOHive`r`n"
            $lgpoout += "$RegKeyPath`r`n"
            If($AllValues){
                $lgpoout += "*`r`n"
                $lgpoout += "DELETEALLVALUES`r`n"
            }Else{
                $lgpoout += "$RegKeyName`r`n"
                $lgpoout += "DELETE`r`n"
            }
            $lgpoout += "$RegKeyName`r`n"
            $lgpoout += "DELETE`r`n"
            $lgpoout += "`r`n"
            $lgpoout | Out-File "$env:Temp\$LgpoFileName" -Force

            If($VerbosePreference){$lgpoargs = "/v /q /t"}Else{$lgpoargs="/q /t"}

            If($WhatIfPreference)
            {
                Write-Output ("What if: Performing the operation ""Start-Process"" on target ""{1}"" with argument ""$lgpoargs $env:Temp\$LgpoFileName /v""." -f ${CmdletName},$LGPOBinaryPath)
            }
            Else
            {
                Write-Verbose ("{0} :: Start-Process {1} -ArgumentList '/t {2}' -RedirectStandardError '{3}' -RedirectStandardOutput '{4}' -Wait -NoNewWindow -PassThru" -f ${CmdletName},$LGPOBinaryPath,"$env:Temp\$LgpoFileName","$env:Temp\$LgpoFileName.stderr","$env:Temp\$LgpoFileName.stdout")
                Try{
                    $result = Start-Process $LGPOBinaryPath -ArgumentList "$lgpoargs $env:Temp\$LgpoFileName /v" -RedirectStandardError "$env:Temp\$LgpoFileName.stderr" -RedirectStandardOutput "$env:Temp\$LgpoFileName.stdout" -Wait -NoNewWindow -PassThru -ErrorAction Stop
                    Write-Verbose ("{0} :: LGPO ran successfully." -f ${CmdletName})
                }
                Catch{
                    Write-Error ("{0} :: LGPO failed to run.{1}" -f ${CmdletName},$result.ExitCode)
                }
            }

        }
        Else{
            Write-Error ("{0} :: Local Policy was not set; LGPO binaries not found in path [{1}]. Download binaries from 'https://www.microsoft.com/en-us/download/details.aspx?id=55319' " -f ${CmdletName},$LGPOBinaryPath)
        }

        If($Force)
        {
            If($AllValues){
                Write-Verbose ("{0} :: Force enabled. Removing all registry keys from [{1}\{2}]" -f ${CmdletName},$RegHive,$RegKeyPath)
                #verify the registry value has been set
                Try{
                    Remove-ItemProperty -Path $RegPath -Name * -Force -WhatIf:$WhatIfPreference -ErrorAction Stop | Out-Null
                }
                Catch{
                    Write-Error ("{0} :: Unable to remove registry keys from [{1}\{2}]. {3}" -f ${CmdletName},$RegHive,$RegKeyPath,$_.Exception.Message)
                }
            }
            Else{
                Write-Verbose ("{0} :: Force enabled. Removing registry keys [{1}\{2}\{3}]" -f ${CmdletName},$RegHive,$RegKeyPath,$RegKeyName)
                #verify the registry value has been set
                Try{
                    Write-Verbose ("{0} :: Removing key name [{2}] at path [{1}]" -f ${CmdletName},($RegHive +'\'+ $RegKeyPath),$RegKeyName)
                    Remove-ItemProperty -Path $RegPath -Name $RegKeyName -Force -WhatIf:$WhatIfPreference -ErrorAction Stop | Out-Null
                }
                Catch{
                    Write-Error ("{0} :: Unable to remove registry key [{1}\{2}\{3}]. {4}" -f ${CmdletName},$RegHive,$RegKeyPath,$RegKeyName,$_.Exception.Message)
                }
            }
            
        }
    }
    End {
        #cleanup LGPO temp files
        If( (Test-Path "$env:Temp\$LgpoFileName" -PathType Leaf) -and !$WhatIfPreference){
               Remove-Item "$env:Temp\$LgpoFileName" -ErrorAction SilentlyContinue -Force | Out-Null
        }
    }

}


### -----------------------------------
### Set-LocalUserPolicySetting Cmdlet
### -----------------------------------

Function Set-LocalUserPolicySetting {
    <#
        .SYNOPSIS
        Converts registry key into GPO for user policy

        .DESCRIPTION
        Uses LGPO tool to convert registry key into Local policy

        .NOTES
        Download LGPO from https://www.microsoft.com/en-us/download/details.aspx?id=55319
        Create a Directory in C:\ProgramData\LGPO
        Unzip LGPO.exe to that folder

        .PARAMETER RegPath
        Required. Specify path to registry item

        .PARAMETER Name
        Specify Name of registry key to set. If no name specified, RegPath will be split up to use leaf as name

        .PARAMETER Type
        Default to 'DWord'. Specify type of registry item

        .PARAMETER Value
        Specify value or Key name

        .PARAMETER ApplyTo
        Defaults to AllUsers. Specify either defaultuser or CurrentUser

        .PARAMETER Force
        If LGPO failed, this will set the registry item anyway

        .PARAMETER LGPOBinaryPath
        Defaults to "C:\ProgramData\LGPO\LGPO.exe". Download LGPO from https://www.microsoft.com/en-us/download/details.aspx?id=55319. Use this to specify alternate location

        .EXAMPLE
        Set-LocalUserPolicySetting -RegPath 'SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'DisableNotificationCenter' -Type DWord -Value 1
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [Alias("Path")]
        [string]$RegPath,

        [Parameter(Mandatory=$false,Position=1)]
        [Alias("v")]
        [string]$Name,

        [Parameter(Mandatory=$false,Position=2)]
        [ValidateSet('None','String','Binary','DWord','ExpandString','MultiString','QWord')]
        [Alias("PropertyType","t")]
        [string]$Type = 'DWord',

        [Parameter(Mandatory=$false,Position=3)]
        [Alias("d")]
        $Value,

        [Parameter(Mandatory=$false)]
        [ValidateSet('CurrentUser','AllUsers','DefaultUser')]
        [Alias("Users")]
        [string]$ApplyTo = 'AllUsers',

        [Parameter(Mandatory=$false)]
        [Alias("f")]
        [switch]$Force,

        [Parameter(Mandatory=$false)]
        [ValidateScript({Test-path $_ -PathType Leaf})]
        $LGPOBinaryPath = "$env:ALLUSERSPROFILE\LGPO\LGPO.exe"
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


        # Get each user profile SID and Path to the profile
        $AllProfiles = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*" | Where-Object {$_.PSChildName -match "S-1-5-21-(\d+-?){4}$" } |
                Select-Object @{Name="SID"; Expression={$_.PSChildName}}, @{Name="UserHive";Expression={"$($_.ProfileImagePath)\NTuser.dat"}}, @{Name="UserName";Expression={Split-Path $_.ProfileImagePath -Leaf}}

        # Add in the DEFAULT User Profile (Not be confused with .DEFAULT)
        $DefaultProfile = "" | Select-Object SID, UserHive,UserName
        $DefaultProfile.SID = "DEFAULT"
        $DefaultProfile.Userhive = "$env:systemdrive\Users\Default\NTUSER.dat"
        $DefaultProfile.UserName = "Default"

        #Add it to the UserProfile list
        $UserProfiles = @()
        $UserProfiles += $AllProfiles
        $UserProfiles += $DefaultProfile

        #get current users sid
        [string]$CurrentSID = (Get-CimInstance Win32_UserAccount | Where-Object {$_.name -eq $env:username}).SID

        Write-Verbose ("{0} :: Found [{1}] user profiles" -f ${CmdletName},$UserProfiles.count)
    }
    Process
    {
        #grab the hive from the regpath
        $RegKeyHive = ($RegPath).Split('\')[0].Replace('Registry::','').Replace(':','')

        #Grab user keys and profiles based on whom it will be applied to
        Switch($ApplyTo){
            'AllUsers'      {$RegHive = 'HKEY_USERS'; $ProfileList = $UserProfiles}
            'CurrentUser'   {$RegHive = 'HKCU'      ; $ProfileList = ($UserProfiles | Where-Object{$_.SID -eq $CurrentSID})}
            'DefaultUser'   {$RegHive = 'HKU'       ; $ProfileList = $DefaultProfile}
            default         {$RegHive = $RegKeyHive ; $ProfileList = ($UserProfiles | Where-Object{$_.SID -eq $CurrentSID})}
        }

        #check if hive is local machine.
        If($RegKeyHive -match "HKEY_LOCAL_MACHINE|HKLM|HKCR"){
            Write-Output ("{0} :: Registry path [{1}] is not a user path. Use 'Remove-LocalPolicySetting' cmdlet instead" -f ${CmdletName},$RegKeyHive)
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
            Write-Output ("{0} :: User registry hive was not found or specified in key path [{1}]. Either use the -ApplyTo Switch or specify user hive [eg. HKCU\]" -f ${CmdletName},$RegPath)
            return
        }

        #loop through profiles as long as the hive is not the current user hive
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
                Write-Verbose ("{0} :: Setting policy [{1}] for user: {2}" -f ${CmdletName},$RegKeyName,$UserName)

                #loadhive if not mounted
                If (($HiveLoaded = Test-Path Registry::HKEY_USERS\$($UserProfile.SID)) -eq $false) {
                    Start-Process -FilePath "CMD.EXE" -ArgumentList "/C REG.EXE LOAD HKU\$($UserProfile.SID) $($UserProfile.UserHive)" -Wait -WindowStyle Hidden
                    $HiveLoaded = $true
                }

                If ($HiveLoaded -eq $true) {
                    Set-LocalPolicySetting -Path "$RegHive\$($UserProfile.SID)\$RegKeyPath" -Name $RegKeyName -Type $Type -Value $Value -LGPOBinaryPath $LGPOBinaryPath -Force:$Force  -WhatIf:$WhatIfPreference
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
            Set-LocalPolicySetting -Path "$RegHive\$RegKeyPath" -Name $RegKeyName -Type $Type -Value $Value -LGPOBinaryPath $LGPOBinaryPath -Force:$Force -WhatIf:$WhatIfPreference
        }

    }
}



### -----------------------------------
### Remove-LocalUserPolicySetting Cmdlet
### -----------------------------------

Function Remove-LocalUserPolicySetting {
    <#
        .SYNOPSIS
        Removes GPO setting on user

        .DESCRIPTION
        Uses LGPO tool to remove user policy settings or registry key

        .NOTES
        Download LGPO from https://www.microsoft.com/en-us/download/details.aspx?id=55319
        Create a Directory in C:\ProgramData\LGPO
        Unzip LGPO.exe to that folder

        .PARAMETER RegPath
        Required. Specify path to registry item

        .PARAMETER Name
        Specify Name of registry key to remove. If no name specified, RegPath will be split up to use leaf as name

        .PARAMETER ApplyTo
        Defaults to AllUsers. Specify either defaultuser or CurrentUser

        .PARAMETER Force
        If LGPO failed, this will remove the registry item anyway

        .PARAMETER LGPOBinaryPath
        Defaults to "C:\ProgramData\LGPO\LGPO.exe". Download LGPO from https://www.microsoft.com/en-us/download/details.aspx?id=55319. Use this to specify alternate location

        .EXAMPLE
        Remove-LocalUserPolicySetting -RegPath 'SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'DisableNotificationCenter'
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [Alias("Path")]
        [string]$RegPath,

        [Parameter(Mandatory=$false,Position=1)]
        [Alias("v")]
        [string]$Name,

        [Parameter(Mandatory=$false)]
        [ValidateSet('CurrentUser','AllUsers','DefaultUser')]
        [Alias("Users")]
        [string]$ApplyTo = 'AllUsers',

        [Parameter(Mandatory=$false)]
        [Alias("f")]
        [switch]$Force,

        [Parameter(Mandatory=$false)]
        [ValidateScript({Test-path $_ -PathType Leaf})]
        $LGPOBinaryPath = "$env:ALLUSERSPROFILE\LGPO\LGPO.exe"
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

        # Get each user profile SID and Path to the profile
        $AllProfiles = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*" | Where-Object {$_.PSChildName -match "S-1-5-21-(\d+-?){4}$" } |
                Select-Object @{Name="SID"; Expression={$_.PSChildName}}, @{Name="UserHive";Expression={"$($_.ProfileImagePath)\NTuser.dat"}}, @{Name="UserName";Expression={Split-Path $_.ProfileImagePath -Leaf}}

        # Add in the DEFAULT User Profile (Not be confused with .DEFAULT)
        $DefaultProfile = "" | Select-Object SID, UserHive,UserName
        $DefaultProfile.SID = "DEFAULT"
        $DefaultProfile.Userhive = "$env:systemdrive\Users\Default\NTUSER.dat"
        $DefaultProfile.UserName = "Default"

        #Add it to the UserProfile list
        $UserProfiles = @()
        $UserProfiles += $AllProfiles
        $UserProfiles += $DefaultProfile

        #get current users sid
        [string]$CurrentSID = (Get-CimInstance Win32_UserAccount | Where-Object {$_.name -eq $env:username}).SID

        Write-Verbose ("{0} :: Found [{1}] user profiles" -f ${CmdletName},$UserProfiles.count)
    }
    Process
    {
        #grab the hive from the regpath
        $RegKeyHive = ($RegPath).Split('\')[0].Replace('Registry::','').Replace(':','')

        #Grab user keys and profiles based on whom it will be applied to
        Switch($ApplyTo){
            'AllUsers'      {$RegHive = 'HKEY_USERS'; $ProfileList = $UserProfiles}
            'CurrentUser'   {$RegHive = 'HKCU'      ; $ProfileList = ($UserProfiles | Where-Object{$_.SID -eq $CurrentSID})}
            'DefaultUser'   {$RegHive = 'HKU'       ; $ProfileList = $DefaultProfile}
            default         {$RegHive = $RegKeyHive ; $ProfileList = ($UserProfiles | Where-Object{$_.SID -eq $CurrentSID})}
        }

        #check if hive is local machine.
        If($RegKeyHive -match "HKEY_LOCAL_MACHINE|HKLM|HKCR"){
            Write-Output ("{0} :: Registry path [{1}] is not a user path. Use 'Set-LocalPolicySetting' cmdlet instead" -f ${CmdletName},$RegKeyHive)
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
            Write-Output ("{0} :: User registry hive was not found or specified in key path [{1}]. Either use the -ApplyTo Switch or specify user hive [eg. HKCU\]" -f ${CmdletName},$RegPath)
            return
        }

        #loop through profiles as long as the hive is not the current user hive
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
                Write-Verbose ("{0} :: Removing policy [{1}] for user: {2}" -f ${CmdletName},$RegKeyName,$UserName)

                #loadhive if not mounted
                If (($HiveLoaded = Test-Path Registry::HKEY_USERS\$($UserProfile.SID)) -eq $false) {
                    Start-Process -FilePath "CMD.EXE" -ArgumentList "/C REG.EXE LOAD HKU\$($UserProfile.SID) $($UserProfile.UserHive)" -Wait -WindowStyle Hidden
                    $HiveLoaded = $true
                }

                If ($HiveLoaded -eq $true) {
                    Remove-LocalPolicySetting -Path "$RegHive\$($UserProfile.SID)\$RegKeyPath" -Name $RegKeyName -LGPOBinaryPath $LGPOBinaryPath -Force:$Force -WhatIf:$WhatIfPreference
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
            Remove-LocalPolicySetting -Path "$RegHive\$RegKeyPath" -Name $RegKeyName -LGPOBinaryPath $LGPOBinaryPath -Force:$Force -WhatIf:$WhatIfPreference
        }

    }
    End {

    }
}

$exportModuleMemberParams = @{
    Function = @(
        'Set-LocalPolicySetting',
        'Remove-LocalPolicySetting',
        'Set-LocalUserPolicySetting',
        'Remove-LocalUserPolicySetting'
    )
}

Export-ModuleMember @exportModuleMemberParams
