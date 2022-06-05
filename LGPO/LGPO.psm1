### -----------------------------------
### Get-LocalPolicySetting Cmdlet
### -----------------------------------
Function Get-LocalPolicySettings {
    <#
        .SYNOPSIS
        Retrieves Local policies

        .DESCRIPTION
        Uses LGPO tool to parse local policies for either machien or user and export as object

        .NOTES
        Download LGPO from https://www.microsoft.com/en-us/download/details.aspx?id=55319
        Create a Directory in C:\ProgramData\LGPO
        Unzip LGPO.exe to that folder

        .PARAMETER Policy
        Required. Specify Computer or User

        .PARAMETER LGPOBinaryPath
        Required. Defaults to "C:\ProgramData\LGPO\LGPO.exe". Download LGPO from https://www.microsoft.com/en-us/download/details.aspx?id=55319. Use this to specify alternate location

        .PARAMETER Filter
        Filter on export

        .EXAMPLE
        Get-LocalPolicySettings -Policy Computer -LGPOBinaryPath "C:\ProgramData\LGPO\LGPO.exe"

        .EXAMPLE
        Get-LocalPolicySettings -Policy Computer -LGPOBinaryPath "C:\ProgramData\LGPO\LGPO.exe" -Filter '$_.Key -like "*microsoft*"'

        .EXAMPLE
        Get-LocalPolicySettings -Policy Computer -LGPOBinaryPath "C:\ProgramData\LGPO\LGPO.exe" -Filter '$_.Name -eq "*"'

        .EXAMPLE
        Get-LocalPolicySettings -Policy Computer -LGPOBinaryPath "C:\ProgramData\LGPO\LGPO.exe" -Verbose

        .EXAMPLE
        Get-LocalPolicySettings -Policy Computer -LGPOBinaryPath "C:\ProgramData\LGPO\LGPO.exe" -Debug
        Working files will be left in temp folder for debugging

        .EXAMPLE
        Get-LocalPolicySettings -Policy Computer -LGPOBinaryPath c:\lgpo\lgpo.exe

        .LINK
        Get-LocalPolicySystemSettings
        Get-LocalPolicyUserSettings
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    Param (
        [Parameter(Mandatory=$true,Position=1)]
        [ValidateSet('Machine','Computer','User')]
        $Policy,

        [Parameter(Mandatory=$true,Position=2)]
        [ValidateScript({Test-path $_ -PathType Leaf})]
        $LGPOBinaryPath,

        [Parameter(Mandatory=$false)]
        [string]$Filter,

        [Parameter(Mandatory=$false)]
        [String]$ExportAsFile
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

        if (-not $PSBoundParameters.ContainsKey('Debug')) {
            $DebugPreference = $PSCmdlet.SessionState.PSVariable.GetValue('DebugPreference')
        }
    }
    Process{
        #Build argumentlist
        $lgpoargs = @()
        $lgpoargs += '/parse'
        If($Policy -eq 'Computer'){
            $lgpoargs += '/m'
            $PolicyPath = 'Machine'
        }Else{
            $lgpoargs += '/u'
            $PolicyPath = 'User'
        }
        $LgpoFileName = ('LGPO-Get-' + $env:COMPUTERNAME + '-' + $Policy + '-Policies')
        $lgpoargs += "$env:Windir\System32\GroupPolicy\$PolicyPath\Registry.pol"

        #convert argument array to string for verbose output
        $lgpoargstr = ($lgpoargs -join ' ')

        Write-Verbose ("{0} : Start-Process {1} -ArgumentList '{2}' -RedirectStandardError '{3}' -RedirectStandardOutput '{4}' -Wait -WindowStyle Hidden -PassThru" -f ${CmdletName},$LGPOBinaryPath,$lgpoargstr,"$env:Temp\$LgpoFileName.stderr","$env:Temp\$LgpoFileName.stdout")
        #run LGPO command
        Try{
            $result = Start-Process $LGPOBinaryPath -ArgumentList $lgpoargs -RedirectStandardError "$env:Temp\$LgpoFileName.stderr" -RedirectStandardOutput "$env:Temp\$LgpoFileName.stdout" -Wait -WindowStyle Hidden -PassThru -ErrorAction Stop
            Write-Verbose ("{0} : LGPO ran successfully." -f ${CmdletName})
        }
        Catch{
            Write-Error ("LGPO failed to run. {1}" -f ${CmdletName},$result.ExitCode)
        }

        #Get only the important content of lgpo export
        $LgpoContent = Get-Content "$env:Temp\$LgpoFileName.stdout"
        $LgpoContentClean = ($LgpoContent |Select-String -Pattern '^;' -NotMatch |Select-String -Pattern '\w+|\*') -split '\n'
        $LineCount = ($LgpoContentClean | Measure-Object -Line).Lines

        #loop through content to build object
        $r = 0
        $line = 0
        $LgpoPolArray = @()
        for ($line = 0; $line -lt $LineCount; $line++)
        {
            #$r = $i
            If($r -eq 0){
                #build object to start
                $LgpoPol = '' | Select Hive,Key,Name,Type,Value
                $LgpoPol.Hive = $LgpoContentClean[$line]
            }
            If($r -eq 1){$LgpoPol.Key = $LgpoContentClean[$line]}
            If($r -eq 2){$LgpoPol.Name = $LgpoContentClean[$line]}
            If($r -eq 3){
                $LgpoPol.Type = $LgpoContentClean[$line].split(':')[0]
                $LgpoPol.Value = $LgpoContentClean[$line].split(':')[1]
                #reset the count after 3 lines
                $r = 0
                #collect data before reset
                $LgpoPolArray += $LgpoPol

            }Else{
                $r++
            }
        }

    }
    End{
         #cleanup LGPO temp files if not debugging
         If( (Test-Path "$env:Temp\$LgpoFileName.stdout" -PathType Leaf) -and !$DebugPreference ){
            Remove-Item "$env:Temp\$LgpoFileName.stderr" -ErrorAction SilentlyContinue -Force | Out-Null
            Remove-Item "$env:Temp\$LgpoFileName.stdout" -ErrorAction SilentlyContinue -Force | Out-Null
        }

        If($Filter){
            $fltr = [ScriptBlock]::Create($Filter)
            $LgpoPolArray | Where-Object $fltr
        }
        Else{
            return $LgpoPolArray
        }
    }
}

### ----------------------------------
### Update-LocalPolicySettings Cmdlet
### ----------------------------------
Function Update-LocalPolicySettings{
    <#
        .SYNOPSIS
        Updates Local policies

        .DESCRIPTION
        Uses LGPO tool to update local policies for either machine or user from data or file

        .NOTES
        Download LGPO from https://www.microsoft.com/en-us/download/details.aspx?id=55319
        Create a Directory in C:\ProgramData\LGPO
        Unzip LGPO.exe to that folder

        .PARAMETER Policy
        Required. Specify Computer or User

        .PARAMETER LGPOBinaryPath
        Required. Defaults to "C:\ProgramData\LGPO\LGPO.exe". Download LGPO from https://www.microsoft.com/en-us/download/details.aspx?id=55319. Use this to specify alternate location

        .PARAMETER LgpoData
        Required. PSObject with properties Hive, Keys, Name, Type, Value

        .PARAMETER LgpoFile
        Required. File path to text file formatted for LGPO import

        .PARAMETER Filter
        Filter on export. Only available when using LgpoData parameter

        .EXAMPLE
        Update-LocalPolicySettings -Policy Computer -LGPOBinaryPath "C:\Temp\LGPO\LGPO.exe" -LgpoData (Get-LocalPolicySystemSettings)

        .EXAMPLE
        Update-LocalPolicySettings -Policy User -LgpoFile C:\policyexport.txt

        .EXAMPLE
        Update-LocalPolicySettings -Policy Computer -LgpoData (Get-LocalPolicySystemSettings -Filter '$_.Key -like "*microsoft*"')

        .EXAMPLE
        Update-LocalPolicySettings -Policy Computer -LgpoData (Get-LocalPolicySystemSettings -Filter '$_.Name -ne "*"') -Verbose

        .EXAMPLE
        (Get-LocalPolicySystemSettings -Filter '$_.Name -ne "*"') | Update-LocalPolicySettings -Policy Computer

        .EXAMPLE
        Update-LocalPolicySettings -Policy Computer -LGPOBinaryPath "C:\ProgramData\LGPO\LGPO.exe" -LgpoData (Get-LocalPolicySystemSettings -Filter '$_.Name -ne "*"') -Debug
        Working files will be left in temp folder for debugging

    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium',DefaultParameterSetName='Data')]
    Param (
        [Parameter(Mandatory=$true,Position=1)]
        [ValidateSet('Machine','Computer','User')]
        $Policy,

        [Parameter(Mandatory=$true,Position=2,ParameterSetName='Data',ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        $LgpoData,

        [Parameter(Mandatory=$true,Position=2,ParameterSetName='File')]
        [ValidateScript({Test-path $_ -PathType Leaf})]
        $LgpoFile,

        [Parameter(Mandatory=$false,ParameterSetName='Data')]
        [string]$Filter,

        [Parameter(Mandatory=$false)]
        [ValidateScript({Test-path $_ -PathType Leaf})]
        $LGPOBinaryPath = "$env:ALLUSERSPROFILE\LGPO\LGPO.exe"
    )
    Begin
    {
        ## Get the name of this function
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

        if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
            $WhatIfPreference = $PSCmdlet.SessionState.PSVariable.GetValue('WhatIfPreference')
        }

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference')
        }

        if (-not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = $PSCmdlet.SessionState.PSVariable.GetValue('ConfirmPreference')
        }

        if (-not $PSBoundParameters.ContainsKey('Debug')) {
            $DebugPreference = $PSCmdlet.SessionState.PSVariable.GetValue('DebugPreference')
        }

        If ($PSCmdlet.ParameterSetName -eq "File") {
            $LgpoFilePath = $LgpoFile
        }

        If ($PSCmdlet.ParameterSetName -eq "Data") {
            # build a unique output file
            $LgpoFileName = ('LGPO-Update-' + $env:COMPUTERNAME + '-' + $Policy + '-Policies')

            #$lgpoout = $null
            $lgpoout = "; ----------------------------------------------------------------------`r`n"
            $lgpoout += "; BUILDING POLICY`r`n"
            $lgpoout += "`r`n"
        }
    }
    Process{

        If ($PSCmdlet.ParameterSetName -eq "Data") {
            If($Filter){
                $fltr = [ScriptBlock]::Create($Filter)
                $LgpoData = $LgpoData | Where-Object $fltr
            }

            Foreach($Item in $LgpoData){
                $lgpoout += "$($Item.Hive)`r`n"
                $lgpoout += "$($Item.Key)`r`n"
                $lgpoout += "$($Item.Name)`r`n"
                If($Item.Value){
                    $lgpoout += "$($Item.Type):$($Item.Value)`r`n"
                }Else{
                    $lgpoout += "$($Item.Type)`r`n"
                }

                $lgpoout += "`r`n"
            }
        }
    }
    End{
        If ($PSCmdlet.ParameterSetName -eq "Data") {
            $lgpoout += "; BUILDING COMPLETED.`r`n"
            $lgpoout += "; ----------------------------------------------------------------------`r`n"
            $lgpoout | Out-File "$env:Temp\$LgpoFileName.lgpo" -Force -WhatIf:$false
        }

        $LgpoFilePath = "$env:Temp\$LgpoFileName.lgpo"

        #check if path is set
        If(Test-Path $LGPOBinaryPath)
        {
            If($Policy -eq 'Computer'){$PolicyPath = 'Machine'}Else{$PolicyPath = 'User'}
            # Build agrument list
            # should look like this: /r path\lgpo.txt /w path\registry.pol [/v]
            $lgpoargs = @()
            $lgpoargs += '/r'
            $lgpoargs += $LgpoFilePath
            $lgpoargs += '/w'
            $lgpoargs += "$env:Windir\System32\GroupPolicy\$PolicyPath\Registry.pol"
            If($VerbosePreference){$lgpoargs += '/v'}

            #convert argument array to string for verbose output
            $lgpoargstr = ($lgpoargs -join ' ')

            #run LGPO command
            If($WhatIfPreference)
            {
                Write-Output ("What if: Performing the operation ""{0}"" on target ""{1}"" with argument ""LGPO {2}""." -f ${CmdletName},$Policy,$lgpoargstr)
            }
            Else{
                #apply policy
                Try{
                    Write-Verbose ("{0} : RUNNING COMMAND: Start-Process {1} -ArgumentList '{2}' -RedirectStandardError '{3}' -RedirectStandardOutput '{4}' -Wait -WindowStyle Hidden -PassThru" -f ${CmdletName},$LGPOBinaryPath,$lgpoargstr,"$env:Temp\$LgpoFileName.stderr","$env:Temp\$LgpoFileName.stdout")
                    $result = Start-Process $LGPOBinaryPath -ArgumentList $lgpoargs -RedirectStandardError "$env:Temp\$LgpoFileName.stderr" -RedirectStandardOutput "$env:Temp\$LgpoFileName.stdout" -Wait -WindowStyle Hidden -PassThru -ErrorAction Stop
                    Write-Verbose ("{0} : LGPO ran successfully." -f ${CmdletName})
                }
                Catch{
                    Write-Error ("LGPO failed to run. {1}" -f ${CmdletName},$result.ExitCode)
                }
                Finally{
                    #cleanup LGPO temp files if not debugging
                    If( (Test-Path "$env:Temp\$LgpoFileName.lgpo" -PathType Leaf) -and !$DebugPreference ){
                        Remove-Item "$env:Temp\$LgpoFileName.lgpo" -ErrorAction SilentlyContinue -Force | Out-Null
                        Remove-Item "$env:Temp\$LgpoFileName.stderr" -ErrorAction SilentlyContinue -Force | Out-Null
                        Remove-Item "$env:Temp\$LgpoFileName.stdout" -ErrorAction SilentlyContinue -Force | Out-Null
                    }
                    Else{
                        Write-Verbose ("View file for debugging: {1}" -f ${CmdletName},$LgpoFilePath)
                    }
                }
            }
        }
        Else{
            Write-Error ("Local Policy was not updated; LGPO binaries not found in path [{1}]. Download binaries from 'https://www.microsoft.com/en-us/download/details.aspx?id=55319' " -f ${CmdletName},$LGPOBinaryPath)
        }
    }
}

### -------------------------------------
### Get-LocalPolicySystemSettings Cmdlet
### -------------------------------------
Function Get-LocalPolicySystemSettings{
    <#
        .SYNOPSIS
        Retrieves Local system policies

        .DESCRIPTION
        Uses LGPO tool to parse local system policy and export as object

        .NOTES
        Download LGPO from https://www.microsoft.com/en-us/download/details.aspx?id=55319
        Create a Directory in C:\ProgramData\LGPO
        Unzip LGPO.exe to that folder

        .PARAMETER Filter
        Filter on export

        .PARAMETER LGPOBinaryPath
        Defaults to "C:\ProgramData\LGPO\LGPO.exe". Download LGPO from https://www.microsoft.com/en-us/download/details.aspx?id=55319. Use this to specify alternate location

        .EXAMPLE
        Get-LocalPolicySystemSettings

        .EXAMPLE
        Get-LocalPolicySystemSettings -Filter '$_.Key -like "*microsoft*"'

        .EXAMPLE
        Get-LocalPolicySystemSettings -Filter '$_.Name -eq "*"'

        .EXAMPLE
        Get-LocalPolicySystemSettings -Verbose

        .EXAMPLE
        Get-LocalPolicySystemSettings -Debug
        Working files will be left in temp folder for debugging

        .EXAMPLE
        Get-LocalPolicySystemSettings -LGPOBinaryPath c:\lgpo\lgpo.exe

        .LINK
        Get-LocalPolicySettings
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    Param (
        [Parameter(Mandatory=$false)]
        [string]$Filter,

        [Parameter(Mandatory=$false)]
        [ValidateScript({Test-path $_ -PathType Leaf})]
        $LGPOBinaryPath = "$env:ALLUSERSPROFILE\LGPO\LGPO.exe"
    )
    Begin
    {
        ## Get the name of this function
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

        if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
            $WhatIfPreference = $PSCmdlet.SessionState.PSVariable.GetValue('WhatIfPreference')
        }
    }
    Process{
        #build splat table
        $LGPOSplat = @{
            Policy='Machine'
            LGPOBinaryPath=$LGPOBinaryPath
        }
        If($Filter){
            $LGPOSplat += @{Filter=$Filter}
        }

        #convert spat hashtable to string for whatif output
        $LGPOSplatString = $LGPOSplat.GetEnumerator() | %{('/' + $_.Key + ' ' + $_.Value) -join ' '} | Select -Last 1

        If($WhatIfPreference)
        {
            Write-Output ("What if: Performing the operation ""{0}"" on target ""{1}"" with argument ""{2}""." -f ${CmdletName},$LGPOSplat.Policy,$LGPOSplatString)
        }
        Else
        {
            Get-LocalPolicySettings @LGPOSplat
        }
    }
}


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
        Required. Specify Name of registry key to set.

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
        Set-LocalPolicySetting -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ImmersiveShell' -Name 'UseActionCenterExperience' -Type DWord -Value 0 -Debug
        Working files will be left in temp folder for debugging

        .EXAMPLE
        Set-LocalPolicySetting -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ImmersiveShell' -Name 'UseActionCenterExperience' -Type DWord -Value 0 -LGPOBinaryPath c:\lgpo\lgpo.exe
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    Param (
        [Parameter(Mandatory=$true,Position=1)]
        [Alias("Path")]
        [string]$RegPath,

        [Parameter(Mandatory=$true,Position=2)]
        [Alias("v")]
        [string]$Name,

        [Parameter(Mandatory=$false,Position=3)]
        [ValidateSet('None','String','Binary','DWord','ExpandString','MultiString','QWord')]
        [Alias("PropertyType","t")]
        $Type = 'DWord',

        [Parameter(Mandatory=$True,Position=4)]
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

        if (-not $PSBoundParameters.ContainsKey('Debug')) {
            $DebugPreference = $PSCmdlet.SessionState.PSVariable.GetValue('DebugPreference')
        }
    }
    Process
    {
        <#TEST SAMPLE
        $RegPath='HKLM\software\policies\microsoft\office\16.0\outlook\cached mode'
        $RegPath='Registry::HKEY_USERS\software\policies\microsoft\office\16.0\outlook\cached mode'
        $RegPath='HKCU:\software\policies\microsoft\office\16.0\outlook\cached mode'
        $RegPath='software\policies\microsoft\office\16.0\outlook\cached mode'
        $Name='enable';$Type='DWord';$Value=1;$ApplyTo='AllUsers';$Force=$true
        #>
        #Attempt to get the key hive from registry path
        $RegKeyHive = ($RegPath).Split('\')[0].TrimEnd(':')

        #Convert RegKeyHive to LGPO compatible variables
        Switch ($RegKeyHive){
            HKEY_LOCAL_MACHINE {$LGPOHive = 'Computer';$RegHive = 'HKLM:';$RegKeyPath = ($RegPath).Split('\',2)[1]}
            MACHINE {$LGPOHive = 'Computer';$RegHive = 'HKLM:';$RegKeyPath = ($RegPath).Split('\',2)[1]}
            HKLM {$LGPOHive = 'Computer';$RegHive = 'HKLM:';$RegKeyPath = ($RegPath).Split('\',2)[1]}
            HKEY_CURRENT_USER {$LGPOHive = 'User';$RegHive = 'HKCU:';$RegKeyPath = ($RegPath).Split('\',2)[1]}
            HKEY_USERS {$LGPOHive = 'User';$RegHive = 'Registry::HKEY_USERS';$RegKeyPath = ($RegPath).Split('\',2)[1]}
            Registry::HKEY_USERS {$LGPOHive = 'User';$RegHive = 'Registry::HKEY_USERS';$RegKeyPath = ($RegPath).Split('\',2)[1]}
            HKCU {$LGPOHive = 'User';$RegHive = 'HKCU:';$RegKeyPath = ($RegPath).Split('\',2)[1]}
            HKU {$LGPOHive = 'User';$RegHive = 'Registry::HKEY_USERS';$RegKeyPath = ($RegPath).Split('\',2)[1]}
            USER {$LGPOHive = 'User';$RegHive = 'HKCU:';$RegKeyPath = ($RegPath).Split('\',2)[1]}
            default {$LGPOHive = 'Computer';$RegHive = 'HKLM:';$RegKeyPath = $RegPath}
        }

        $RegKeyName = $Name

        #The -split operator supports specifying the maximum number of sub-strings to return.
        #Some values may have additional commas in them that we don't want to split (eg. LegalNoticeText)
        [String]$Value = $Value -split ',',2

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

        Write-Verbose ("{0} : Parsing registry [Hive = '{1}', Path = '{2}', Name = '{3}', Value = '{4}', Type = '{5}']" -f ${CmdletName},$RegHive,$RegKeyPath,$RegKeyName,$Value,$LGPORegType)

        #Remove the Username or SID from Registry key path for LGPO to process properly
        $LGPORegKeyPath = $RegKeyPath
        If($LGPOHive -eq 'User'){
            $UserID = $RegKeyPath.Split('\')[0]
            If($UserID -match "DEFAULT|S-1-5-21-(\d+-?){4}$"){
                $LGPORegKeyPath = $RegKeyPath.Replace($UserID+"\","")
            }
        }

        #check if path is set
        If(Test-Path $LGPOBinaryPath)
        {
            # build a unique output file
            $LgpoFileName = ('LGPO-Set-{0}-{1}-{2}' -f $RegKeyHive,$LGPORegKeyPath,$RegKeyName) -replace 'Registry::','' -replace '[\W_]','-'

            #$lgpoout = $null
            $lgpoout = "; ----------------------------------------------------------------------`r`n"
            $lgpoout += "; PROCESSING POLICY`r`n"
            $lgpoout += "; Source file:`r`n"
            $lgpoout += "`r`n"
            $lgpoout += "$LGPOHive`r`n"
            $lgpoout += "$LGPORegKeyPath`r`n"
            $lgpoout += "$RegKeyName`r`n"
            $lgpoout += "$($LGPORegType):$Value`r`n"
            $lgpoout += "`r`n"

            #complete LGPO file
            Write-Verbose ("{0} : Generating LGPO configuration file [{1}]" -f ${CmdletName},"$env:Temp\$LgpoFileName.lgpo")
            $lgpoout | Out-File "$env:Temp\$LgpoFileName.lgpo" -Force

            # Build agrument list
            # should look like this: /q /t path\lgpo.txt [/v]
            $lgpoargs = @()
            $lgpoargs += '/q'
            $lgpoargs += '/t'
            $lgpoargs += "$env:Temp\$LgpoFileName.lgpo"
            If($VerbosePreference){$lgpoargs += '/v'}

            #convert argument array to string for verbose output
            $lgpoargstr = ($lgpoargs -join ' ')

            If($WhatIfPreference)
            {
                Write-Output ("What if: Performing the operation ""{0}"" on target ""{1}"" with argument ""{2} {3}""." -f ${CmdletName},$LGPOHive,$LGPOBinaryPath,$lgpoargstr)
            }
            Else
            {
                Write-Verbose ("{0} : RUNNING COMMAND: Start-Process {1} -ArgumentList '{2}' -RedirectStandardError '{3}' -RedirectStandardOutput '{4}' -Wait -WindowStyle Hidden -PassThru" -f ${CmdletName},$LGPOBinaryPath,$lgpoargstr,"$env:Temp\$LgpoFileName.stderr","$env:Temp\$LgpoFileName.stdout")
                Try{
                    $result = Start-Process $LGPOBinaryPath -ArgumentList $lgpoargs -RedirectStandardError "$env:Temp\$LgpoFileName.stderr" -RedirectStandardOutput "$env:Temp\$LgpoFileName.stdout" -Wait -WindowStyle Hidden -PassThru -ErrorAction Stop
                    Write-Verbose ("{0} : LGPO ran successfully." -f ${CmdletName})
                }
                Catch{
                    Write-Error ("LGPO failed to run. {1}" -f ${CmdletName},$result.ExitCode)
                }
            }

        }
        Else{
            Write-Error ("Local Policy was not set; LGPO binaries not found in path [{1}]. Download binaries from 'https://www.microsoft.com/en-us/download/details.aspx?id=55319' " -f ${CmdletName},$LGPOBinaryPath)
        }

        If($Force -eq $true)
        {
            #rebuild full path with hive
            $RegPath = ($RegHive +'\'+ $RegKeyPath)

            Write-Verbose ("{0} : Force enabled. Hard coding registry key..." -f ${CmdletName})
            #verify the registry value has been set
            $CurrentPos = $null
            #loop through each key path to build the correct path
            #TEST $Node = $RegPath.split('\')[0]
            Foreach($Node in $RegPath.split('\'))
            {
                $CurrentPos += $Node + '\'
                If(-Not(Test-Path $CurrentPos -PathType Container)){
                    Write-Verbose ("{0} : Building key path [{1}]" -f ${CmdletName},$CurrentPos)
                    New-Item $CurrentPos -ErrorAction SilentlyContinue -WhatIf:$WhatIfPreference | Out-Null
                }
            }

            Try{
                Write-Verbose ("{0} : Setting key name [{2}] at path [{1}] with value [{3}]" -f ${CmdletName},$RegPath,$RegKeyName,$Value)
                Set-ItemProperty -Path $RegPath -Name $RegKeyName -Value $Value -Force:$Force -WhatIf:$WhatIfPreference -ErrorAction Stop
            }
            Catch{
                Write-Error ("Unable to set registry key [{2}={3}] in path [{1}]. {4}" -f ${CmdletName},$RegPath,$RegKeyName,$Value,$_.Exception.Message)
            }
        }
    }
    End {
        #cleanup LGPO temp files if not debugging
        If( (Test-Path "$env:Temp\$LgpoFileName.lgpo" -PathType Leaf) -and !$DebugPreference ){
            Remove-Item "$env:Temp\$LgpoFileName.lgpo" -ErrorAction SilentlyContinue -Force | Out-Null
            Remove-Item "$env:Temp\$LgpoFileName.stderr" -ErrorAction SilentlyContinue -Force | Out-Null
            Remove-Item "$env:Temp\$LgpoFileName.stdout" -ErrorAction SilentlyContinue -Force | Out-Null
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

        .PARAMETER Enforce
        Applies a policy to always delete value instead of removing it from policy (does not show in gpresults)

        .PARAMETER LGPOBinaryPath
        Defaults to "C:\ProgramData\LGPO\LGPO.exe". Download LGPO from https://www.microsoft.com/en-us/download/details.aspx?id=55319. Use this to specify alternate location

        .EXAMPLE
        Remove-LocalPolicySetting -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarMn'

        .EXAMPLE
        Remove-LocalPolicySetting -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ImmersiveShell' -Name 'UseActionCenterExperience' -Enforce

        .EXAMPLE
        Remove-LocalPolicySetting -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ImmersiveShell' -Name 'UseActionCenterExperience' -Verbose

        .EXAMPLE
        Remove-LocalPolicySetting -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ImmersiveShell' -Name 'UseActionCenterExperience' -LGPOBinaryPath c:\lgpo\lgpo.exe

        .LINK
        Get-LocalPolicySystemSettings
        Update-LocalPolicySettings

    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium',DefaultParameterSetName='name')]
    Param (
        [Parameter(Mandatory=$true,Position=1,ParameterSetName="name")]
        [Parameter(Mandatory=$true,Position=1,ParameterSetName="all")]
        [Alias("Path")]
        [string]$RegPath,

        [Parameter(Mandatory=$true,Position=2,ParameterSetName="name")]
        [Alias("v")]
        [string]$Name,

        [Parameter(Mandatory=$true,Position=2,ParameterSetName="all")]
        [Alias("a")]
        [switch]$AllValues,

        [Parameter(Mandatory=$false)]
        [Alias("f")]
        [switch]$Enforce,

        [Parameter(Mandatory=$false,HelpMessage="Default path is 'C:\ProgramData\LGPO\LGPO.exe. If this does not exists you must specify path")]
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

        if (-not $PSBoundParameters.ContainsKey('Debug')) {
            $DebugPreference = $PSCmdlet.SessionState.PSVariable.GetValue('DebugPreference')
        }
    }
    Process
    {
        #Attempt to get the key hive from registry path
        #Attempt to get the key hive from registry path
        $RegKeyHive = ($RegPath).Split('\')[0].TrimEnd(':')

        #Convert RegKeyHive to LGPO compatible variables
        Switch ($RegKeyHive){
            HKEY_LOCAL_MACHINE {$LGPOHive = 'Computer';$RegHive = 'HKLM:';$RegKeyPath = ($RegPath).Split('\',2)[1]}
            MACHINE {$LGPOHive = 'Computer';$RegHive = 'HKLM:';$RegKeyPath = ($RegPath).Split('\',2)[1]}
            HKLM {$LGPOHive = 'Computer';$RegHive = 'HKLM:';$RegKeyPath = ($RegPath).Split('\',2)[1]}
            HKEY_CURRENT_USER {$LGPOHive = 'User';$RegHive = 'HKCU:';$RegKeyPath = ($RegPath).Split('\',2)[1]}
            HKEY_USERS {$LGPOHive = 'User';$RegHive = 'Registry::HKEY_USERS';$RegKeyPath = ($RegPath).Split('\',2)[1]}
            Registry::HKEY_USERS {$LGPOHive = 'User';$RegHive = 'Registry::HKEY_USERS';$RegKeyPath = ($RegPath).Split('\',2)[1]}
            HKCU {$LGPOHive = 'User';$RegHive = 'HKCU:';$RegKeyPath = ($RegPath).Split('\',2)[1]}
            HKU {$LGPOHive = 'User';$RegHive = 'Registry::HKEY_USERS';$RegKeyPath = ($RegPath).Split('\',2)[1]}
            USER {$LGPOHive = 'User';$RegHive = 'HKCU:';$RegKeyPath = ($RegPath).Split('\',2)[1]}
            default {$LGPOHive = 'Computer';$RegHive = 'HKLM:';$RegKeyPath = $RegPath}
        }

        #if Name not specified, grab last value from full path
        # build a unique output file
        If($AllValues){
            $RegKeyName = '*'
        }
        Else{
            $RegKeyName = $Name
        }

        Write-Verbose ("{0} : Parsing registry [Hive = '{1}', Path = '{2}', Name = '{3}', Value = '{4}', Type = '{5}']" -f ${CmdletName},$RegHive,$RegKeyPath,$RegKeyName,$Value,$LGPORegType)

        #Remove the Username or SID from Registry key path
        $LGPORegKeyPath = $RegKeyPath
        If($LGPOHive -eq 'User'){
            $UserID = $RegKeyPath.Split('\')[0]
            If($UserID -match "DEFAULT|S-1-5-21-(\d+-?){4}$"){
                $LGPORegKeyPath = $RegKeyPath.Replace($UserID+"\","")
            }
        }

        #check if path is set
        If(Test-Path $LGPOBinaryPath)
        {
            If($Enforce -eq $true){
                # build a unique output file
                <# TEST SAMPLE
                $LgpoFileName = 'LGPO-Set-HKEY_USERS\Registry::HKEY_USER\S-S-1-5-21-748411717-568772137-1603165583-500\software\policies\microsoft\office\16.0\outlook-cachedmode-enable.lgpo'
                #>
                If($AllValues){
                    $LgpoFileName = ('LGPO-Set-{0}-{1}-All-Keys' -f $RegKeyHive,$LGPORegKeyPath) -replace 'Registry::','' -replace '[\W_]','-'
                }
                Else{
                    $LgpoFileName = ('LGPO-Set-{0}-{1}-{2}' -f $RegKeyHive,$LGPORegKeyPath,$RegKeyName) -replace 'Registry::','' -replace '[\W_]','-'
                }

                #$lgpoout = $null
                $lgpoout = "; ----------------------------------------------------------------------`r`n"
                $lgpoout += "; PROCESSING POLICY`r`n"
                $lgpoout += "; Source file:`r`n"
                $lgpoout += "`r`n"
                $lgpoout += "$LGPOHive`r`n"
                $lgpoout += "$LGPORegKeyPath`r`n"
                If($AllValues){
                    $lgpoout += "*`r`n"
                    $lgpoout += "DELETEALLVALUES`r`n"
                }Else{
                    $lgpoout += "$RegKeyName`r`n"
                    $lgpoout += "DELETE`r`n"
                }
                $lgpoout += "`r`n"

                #complete LGPO file
                Write-Verbose ("{0} : Generating LGPO configuration file [{1}]" -f ${CmdletName},"$env:Temp\$LgpoFileName.lgpo")
                $lgpoout | Out-File "$env:Temp\$LgpoFileName.lgpo" -Force

                # Build agrument list
                # should look like this: /q /t path\lgpo.txt [/v]
                $lgpoargs = @()
                $lgpoargs += '/q'
                $lgpoargs += '/t'
                $lgpoargs += "$env:Temp\$LgpoFileName.lgpo"
                If($VerbosePreference){$lgpoargs += '/v'}

                #convert argument array to string for verbose output
                $lgpoargstr = ($lgpoargs -join ' ')

                If($WhatIfPreference)
                {
                    Write-Output ("What if: Performing the operation ""{0}"" on target ""{1}"" with argument ""{2} {3}""." -f ${CmdletName},$LGPOHive,$LGPOBinaryPath,$lgpoargstr)
                }
                Else
                {
                    Write-Verbose ("{0} : Start-Process {1} -ArgumentList '{2}' -RedirectStandardError '{3}' -RedirectStandardOutput '{4}' -Wait -WindowStyle Hidden -PassThru" -f ${CmdletName},$LGPOBinaryPath,$lgpoargstr,"$env:Temp\$LgpoFileName.stderr","$env:Temp\$LgpoFileName.stdout")
                    Try{
                        $result = Start-Process $LGPOBinaryPath -ArgumentList $lgpoargs -RedirectStandardError "$env:Temp\$LgpoFileName.stderr" -RedirectStandardOutput "$env:Temp\$LgpoFileName.stdout" -Wait -WindowStyle Hidden -PassThru -ErrorAction Stop
                        Write-Verbose ("{0} : LGPO ran successfully." -f ${CmdletName})
                    }
                    Catch{
                        Write-Error ("LGPO failed to run. {0}" -f $result.ExitCode)
                    }
                }
            }
            Else{
                #TEST (Get-LocalPolicySystemSettings -Filter '$_.Name -ne "*"')
                #TEST $LgpoData | where{$_.Name -ne "ConcatenateDefaults_AllowFresh" -or $_.Key -ne "Software\Policies\Microsoft\Windows\CredentialsDelegation"}

                Try{
                    #Grab all polices but filter out the one that needs be removed. Then update the entire system policy (this set thte removed policy as not configured)
                    If($RegKeyName -ne '*' ){
                        Write-Verbose ("{0} : RUNNING CMDLET: Get-LocalPolicySystemSettings -Filter ('`$_.Name -ne `"$RegKeyName`" -or `$_.Key -ne `"$RegKeyPath`"') | Update-LocalPolicySettings -Policy $LGPOHive -ErrorAction Stop" -f ${CmdletName})
                        Get-LocalPolicySystemSettings -Filter ('$_.Name -ne "' + $RegKeyName + '" -or $_.Key -ne "' + $RegKeyPath + '"') | Update-LocalPolicySettings -Policy $LGPOHive -ErrorAction Stop
                        #Get-LocalPolicySystemSettings | Where {$_.Name -ne $RegKeyName -or $_.Key -ne $RegKeyPath} | Update-LocalPolicySettings -Policy $LGPOHive -ErrorAction Stop
                    }
                    Else{
                        Write-Verbose ("{0} : RUNNING CMDLET: Get-LocalPolicySystemSettings -Filter ('`$_.Key -ne `"$RegKeyPath`"') | Update-LocalPolicySettings -Policy $LGPOHive -ErrorAction Stop" -f ${CmdletName})
                        Get-LocalPolicySystemSettings -Filter ('$_.Key -ne "' + $RegKeyPath + '"') | Update-LocalPolicySettings -Policy $LGPOHive -ErrorAction Stop
                    }
                }
                Catch{
                    Write-Error ("LGPO failed to run. {1}" -f ${CmdletName},$_.Exception.Message)
                }
                Finally{
                    #rebuild full path with hive
                    $RegPath = ($RegHive +'\'+ $RegKeyPath)

                    IF( $PSBoundParameters.ContainsKey('Enforce') ){
                        If($AllValues){
                            $VerboseMsg = ("{0} : Force enabled. Removing all registry keys from [{1}\{2}]" -f ${CmdletName},$RegHive,$RegKeyPath)
                            $ErrorMsg = ("{0} : Unable to remove registry keys from [{1}\{2}]. {3}" -f ${CmdletName},$RegHive,$RegKeyPath,$_.Exception.Message)
                        }
                        Else{
                            $VerboseMsg = ("{0} : Force enabled. Removing registry key [{3}] from [{1}\{2}]" -f ${CmdletName},$RegHive,$RegKeyPath,$RegKeyName)
                            $ErrorMsg = ("{0} : Unable to remove registry key [{1}\{2}\{3}]. {4}" -f ${CmdletName},$RegHive,$RegKeyPath,$RegKeyName,$_.Exception.Message)
                        }

                        Write-Verbose $VerboseMsg
                        #verify the registry value has been set
                        Try{
                            Remove-ItemProperty -Path $RegPath -Name $RegKeyName -Force -WhatIf:$WhatIfPreference -ErrorAction SilentlyContinue
                        }
                        Catch{
                            Write-Error $ErrorMsg
                        }
                    }
                }
            }

        }
        Else{
            Write-Error ("Local Policy was not set; LGPO binaries not found in path [{1}]. Download binaries from 'https://www.microsoft.com/en-us/download/details.aspx?id=55319' " -f ${CmdletName},$LGPOBinaryPath)
        }
    }
    End {
        #cleanup LGPO temp files if not debugging
        If( (Test-Path "$env:Temp\$LgpoFileName.lgpo" -PathType Leaf) -and !$DebugPreference ){
               Remove-Item "$env:Temp\$LgpoFileName.lgpo" -ErrorAction SilentlyContinue -Force | Out-Null
               Remove-Item "$env:Temp\$LgpoFileName.stderr" -ErrorAction SilentlyContinue -Force | Out-Null
               Remove-Item "$env:Temp\$LgpoFileName.stdout" -ErrorAction SilentlyContinue -Force | Out-Null
        }
    }

}


### -----------------------------------
### Get-LocalPolicySetting Cmdlet
### -----------------------------------
Function Get-LocalPolicyUserSettings {
    <#
        .SYNOPSIS
        Retrieves Local user policies

        .DESCRIPTION
        Uses LGPO tool to parse local user policy and export as object

        .NOTES
        Download LGPO from https://www.microsoft.com/en-us/download/details.aspx?id=55319
        Create a Directory in C:\ProgramData\LGPO
        Unzip LGPO.exe to that folder

        .PARAMETER Filter
        Filter on export

        .PARAMETER LGPOBinaryPath
        Defaults to "C:\ProgramData\LGPO\LGPO.exe". Download LGPO from https://www.microsoft.com/en-us/download/details.aspx?id=55319. Use this to specify alternate location

        .EXAMPLE
        Get-LocalPolicyUserSettings

        .EXAMPLE
        Get-LocalPolicyUserSettings -Filter '$_.Key -like "*microsoft*"'

        .EXAMPLE
        Get-LocalPolicyUserSettings -Verbose

        .EXAMPLE
        Get-LocalPolicyUserSettings -Debug
        Working files will be left in temp folder for debugging

        .EXAMPLE
        Get-LocalPolicyUserSettings -LGPOBinaryPath c:\lgpo\lgpo.exe

        .LINK
        Get-LocalPolicySettings
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    Param (
        [Parameter(Mandatory=$false)]
        [string]$Filter,

        [Parameter(Mandatory=$false)]
        [ValidateScript({Test-path $_ -PathType Leaf})]
        $LGPOBinaryPath = "$env:ALLUSERSPROFILE\LGPO\LGPO.exe"
    )
    Begin
    {
        ## Get the name of this function
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

        if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
            $WhatIfPreference = $PSCmdlet.SessionState.PSVariable.GetValue('WhatIfPreference')
        }
    }
    Process{
        $LGPOSplat = @{
            Policy='User'
            LGPOBinaryPath=$LGPOBinaryPath
        }

        If($Filter){
            $LGPOSplat += @{Filter=$Filter}
        }
        $LGPOSplatString = $LGPOSplat.GetEnumerator() | %{('/' + $_.Key + ' ' + $_.Value) -join ' '} | Select -Last 1

        If($WhatIfPreference)
        {
            Write-Output ("What if: Performing the operation ""{0}"" on target ""{1}"" with argument ""{2}""." -f ${CmdletName},$LGPOSplat.Policy,$LGPOSplatString)
        }
        Else
        {
            Get-LocalPolicySettings @LGPOSplat
        }
    }
}

### -----------------------------------
### Set-LocalPolicyUserSetting Cmdlet
### -----------------------------------
Function Set-LocalPolicyUserSetting {
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


        .PARAMETER LGPOBinaryPath
        Defaults to "C:\ProgramData\LGPO\LGPO.exe". Download LGPO from https://www.microsoft.com/en-us/download/details.aspx?id=55319. Use this to specify alternate location

        .EXAMPLE
        Set-LocalPolicyUserSetting -RegPath 'SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'DisableNotificationCenter' -Type DWord -Value 1

        .LINK
        Set-LocalPolicySetting
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    Param (
        [Parameter(Mandatory=$true,Position=1)]
        [Alias("Path")]
        [string]$RegPath,

        [Parameter(Mandatory=$true,Position=2)]
        [Alias("v")]
        [string]$Name,

        [Parameter(Mandatory=$false,Position=3)]
        [ValidateSet('None','String','Binary','DWord','ExpandString','MultiString','QWord')]
        [Alias("PropertyType","t")]
        [string]$Type = 'DWord',

        [Parameter(Mandatory=$false,Position=4)]
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

        Write-Verbose ("{0} : Found [{1}] user profiles" -f ${CmdletName},$UserProfiles.count)
    }
    Process
    {
        <#TEST SAMPLE
        $RegPath='HKLM\software\policies\microsoft\office\16.0\outlook\cached mode'
        $RegPath='Registry::HKEY_USERS\software\policies\microsoft\office\16.0\outlook\cached mode'
        $RegPath='HKCU:\software\policies\microsoft\office\16.0\outlook\cached mode'
        $RegPath='software\policies\microsoft\office\16.0\outlook\cached mode'
        $Name='enable';$Type='DWord';$Value=1;$ApplyTo='AllUsers';$Force=$true
        #>
        #grab the hive from the regpath
        $RegKeyHive = ($RegPath).Split('\')[0].Replace('Registry::','').Replace(':','')
        #detect if first valus has hive; otherwise assume allusers
        If( -Not(Test-Path "$($RegKeyHive):" -PathType Container) ){
            $RegKeyHive = 'HKCU'
            $RegKeyPath = $RegPath
        }
        Else{
            #if Name not specified, grab last value from full path
            $RegKeyPath = ($RegPath).Split('\',2)[1]
            $RegKeyName = $Name
        }

        #Grab user keys and profiles based on whom it will be applied to
        Switch($ApplyTo){
            'AllUsers'      {$RegHive = 'Registry::HKEY_USERS'; $ProfileList = $UserProfiles}
            'CurrentUser'   {$RegHive = 'HKCU'      ; $ProfileList = ($UserProfiles | Where-Object{$_.SID -eq $CurrentSID})}
            'DefaultUser'   {$RegHive = 'HKU'       ; $ProfileList = $DefaultProfile}
        }

        #Overwrite hive value in key path is apply hive is found
        If($RegHive){
            $RegKeyHive = $RegHive
        }

        #check if hive is local machine.
        If($RegKeyHive -match "HKEY_LOCAL_MACHINE|HKLM|HKCR"){
            Write-Error ("Registry path [{1}] is not a user path. Use 'Remove-LocalPolicySetting' cmdlet instead" -f ${CmdletName},$RegKeyHive)
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
                Write-Verbose ("{0} : Setting policy [{1}] for user: {2}" -f ${CmdletName},$RegKeyName,$UserName)

                #loadhive if not mounted
                If (($HiveLoaded = Test-Path "Registry::HKEY_USERS\$($UserProfile.SID)") -eq $false) {
                    Start-Process -FilePath "CMD.EXE" -ArgumentList "/C REG.EXE LOAD HKU\$($UserProfile.SID) $($UserProfile.UserHive)" -Wait -WindowStyle Hidden
                    $HiveLoaded = $true
                }

                If ($HiveLoaded -eq $true) {
                    Write-Verbose ("{0} : RUNNING CMDLET: Set-LocalPolicySetting -Path `"$RegHive\$($UserProfile.SID)\$RegKeyPath`" -Name $RegKeyName -Type $Type -Value $Value -LGPOBinaryPath $LGPOBinaryPath -EnForce:$EnForce -WhatIf:$WhatIfPreference" -f ${CmdletName})
                    Set-LocalPolicySetting -Path "$RegHive\$($UserProfile.SID)\$RegKeyPath" -Name $RegKeyName -Type $Type -Value $Value -LGPOBinaryPath $LGPOBinaryPath -Force:$Force -WhatIf:$WhatIfPreference
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
            Write-Verbose ("{0} : RUNNING CMDLET: Set-LocalPolicySetting -Path `"$RegHive\$RegKeyPath`" -Name $RegKeyName -Type $Type -Value $Value -LGPOBinaryPath $LGPOBinaryPath -EnForce:$EnForce  -WhatIf:$WhatIfPreference" -f ${CmdletName})
            Set-LocalPolicySetting -Path "$RegHive\$RegKeyPath" -Name $RegKeyName -Type $Type -Value $Value -LGPOBinaryPath $LGPOBinaryPath -Force:$Force -WhatIf:$WhatIfPreference
        }

    }
}



### -----------------------------------
### Remove-LocalPolicyUserSetting Cmdlet
### -----------------------------------
Function Remove-LocalPolicyUserSetting {
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
        Remove-LocalPolicyUserSetting -RegPath 'SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'DisableNotificationCenter'

        .LINK
        Remove-LocalPolicySetting
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    Param (
        [Parameter(Mandatory=$true,Position=1)]
        [Alias("Path")]
        [string]$RegPath,

        [Parameter(Mandatory=$false,Position=2)]
        [Alias("v")]
        [string]$Name,

        [Parameter(Mandatory=$false)]
        [ValidateSet('CurrentUser','AllUsers','DefaultUser')]
        [Alias("Users")]
        [string]$ApplyTo = 'AllUsers',

        [Parameter(Mandatory=$false)]
        [Alias("f")]
        [switch]$EnForce,

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

        Write-Verbose ("{0} : Found [{1}] user profiles" -f ${CmdletName},$UserProfiles.count)
    }
    Process
    {
        #grab the hive from the regpath
        $RegKeyHive = ($RegPath).Split('\')[0].Replace('Registry::','').Replace(':','')
        #detect if first valus has hive; otherwise assume allusers
        If( -Not(Test-Path "$($RegKeyHive):" -PathType Container) ){
            $RegKeyHive = 'HKCU'
            $RegKeyPath = $RegPath
        }
        Else{
            #if Name not specified, grab last value from full path
            $RegKeyPath = ($RegPath).Split('\',2)[1]
            $RegKeyName = $Name
        }

        #Grab user keys and profiles based on whom it will be applied to
        Switch($ApplyTo){
            'AllUsers'      {$RegHive = 'Registry::HKEY_USERS'; $ProfileList = $UserProfiles}
            'CurrentUser'   {$RegHive = 'HKCU'      ; $ProfileList = ($UserProfiles | Where-Object{$_.SID -eq $CurrentSID})}
            'DefaultUser'   {$RegHive = 'HKU'       ; $ProfileList = $DefaultProfile}
        }

        #Overwrite hive value in key path is apply hive is found
        If($RegHive){
            $RegKeyHive = $RegHive
        }

        #check if hive is local machine.
        If($RegKeyHive -match "HKEY_LOCAL_MACHINE|HKLM|HKCR"){
            Write-Error ("Registry path [{1}] is not a user path. Use 'Remove-LocalPolicySetting' cmdlet instead" -f ${CmdletName},$RegKeyHive)
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
                Write-Verbose ("{0} : Removing policy [{1}] for user: {2}" -f ${CmdletName},$RegKeyName,$UserName)

                #loadhive if not mounted
                If (($HiveLoaded = Test-Path "Registry::HKEY_USERS\$($UserProfile.SID)") -eq $false) {
                    Start-Process -FilePath "CMD.EXE" -ArgumentList "/C REG.EXE LOAD HKU\$($UserProfile.SID) $($UserProfile.UserHive)" -Wait -WindowStyle Hidden
                    $HiveLoaded = $true
                }

                If ($HiveLoaded -eq $true) {
                    Write-Verbose ("{0} : RUNNING CMDLET: Remove-LocalPolicySetting -Path `"$RegHive\$($UserProfile.SID)\$RegKeyPath`" -Name $RegKeyName -LGPOBinaryPath $LGPOBinaryPath -EnForce:$EnForce -WhatIf:$WhatIfPreference" -f ${CmdletName})
                    Remove-LocalPolicySetting -Path "$RegHive\$($UserProfile.SID)\$RegKeyPath" -Name $RegKeyName -LGPOBinaryPath $LGPOBinaryPath -EnForce:$EnForce -WhatIf:$WhatIfPreference
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
            Write-Verbose ("{0} : RUNNING CMDLET: Remove-LocalPolicySetting -Path `"$RegHive\$RegKeyPath`" -Name $RegKeyName -LGPOBinaryPath $LGPOBinaryPath -EnForce:$EnForce -WhatIf:$WhatIfPreference" -f ${CmdletName})
            Remove-LocalPolicySetting -Path "$RegHive\$RegKeyPath" -Name $RegKeyName -LGPOBinaryPath $LGPOBinaryPath -EnForce:$EnForce -WhatIf:$WhatIfPreference
        }

    }
    End {

    }
}


Function Clear-LocalPolicySettings{
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'High'
    )]
    param(
        [Parameter(Mandatory=$false,Position=1)]
        [ValidateSet('Machine','Computer','User')]
        $Policy,
        $Force
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

        $PolicyPaths = @()
    }
    Process
    {
        If($Policy){
            switch($Policy){
                'Machine' {$PolicyPaths += 'Machine';$GPTarget='Computer'}
                'Computer' {$PolicyPaths += 'Machine';$GPTarget='Computer'}
                'User' {$PolicyPaths += 'User';$GPTarget='User'}
            }
        }
        Else{
            $GPTarget='All'
            $PolicyPaths += 'Machine'
            $PolicyPaths += 'User'
        }

        if ($PSCmdlet.ShouldProcess(($PolicyPaths -join ','))){
            Foreach($PolicyPath in $PolicyPaths){
                Write-Verbose ("{0} : Removing local settings for [{1}]" -f ${CmdletName},$PolicyPath)

                Remove-Item "$env:Windir\System32\GroupPolicy\$PolicyPath\Registry.pol" -Force -WhatIf:$WhatIfPreference -ErrorAction SilentlyContinue | Out-Null
            }
        }
    }
    End{
        If($GPTarget -eq 'All'){
            $GPArgument = '/Force'
        }
        Else{
            $GPArgument = "/Target:$GPTarget /Force"
        }
        Write-Verbose ("{0} : RUNNING COMMAND: Start-Process -FilePath `"gpupdate`" -ArgumentList `"$GPArgument`" -Wait -PassThru -WindowStyle Hidden" -f ${CmdletName})
        Start-Process -FilePath "gpupdate" -ArgumentList "$GPArgument" -Wait -WindowStyle Hidden | Out-Null
    }
}

$exportModuleMemberParams = @{
    Function = @(
        'Get-LocalPolicySystemSettings',
        'Set-LocalPolicySetting',
        'Update-LocalPolicySettings',
        'Remove-LocalPolicySetting',
        'Get-LocalPolicyUserSettings',
        'Set-LocalPolicyUserSetting',
        'Remove-LocalPolicyUserSetting',
        'Clear-LocalPolicySettings'
    )
}

Export-ModuleMember @exportModuleMemberParams
