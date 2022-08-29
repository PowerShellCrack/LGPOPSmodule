### -----------------------------------
### Get-LocalPolicySetting Cmdlet
### -----------------------------------
Function Get-LocalPolicySettings {
    <#
        .SYNOPSIS
        Retrieves Local policies

        .DESCRIPTION
        Uses LGPO tool to parse local policies for either machine or user and export as object

        .NOTES
        Download LGPO from https://www.microsoft.com/en-us/download/details.aspx?id=55319
        Create a Directory in C:\ProgramData\LGPO
        Unzip LGPO.exe to that folder

        .PARAMETER Policy
        Required. Specify Computer or User

        .PARAMETER LGPOBinaryPath
        Use this to specify alternate location
        Defaults to "C:\ProgramData\LGPO\LGPO.exe". Download LGPO from https://www.microsoft.com/en-us/download/details.aspx?id=55319.

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
        #check if path exists
        If(Test-Path $LGPOBinaryPath)
        {
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
        Else{
            Write-Error ("Local Policy cannot be retrieved; LGPO binaries not found in path [{1}].`nDownload binaries from 'https://www.microsoft.com/en-us/download/details.aspx?id=55319' " -f ${CmdletName},$LGPOBinaryPath)
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
        Use this to specify alternate location
        Defaults to "C:\ProgramData\LGPO\LGPO.exe". Download LGPO from https://www.microsoft.com/en-us/download/details.aspx?id=55319.

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

        #check if path exists
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
            Throw ("Local Policy was not updated; LGPO binaries not found in path [{1}].`nDownload binaries from 'https://www.microsoft.com/en-us/download/details.aspx?id=55319' " -f ${CmdletName},$LGPOBinaryPath)
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
        Use this to specify alternate location
        Defaults to "C:\ProgramData\LGPO\LGPO.exe". Download LGPO from https://www.microsoft.com/en-us/download/details.aspx?id=55319.

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
        $LGPOBinaryPath
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
        $LGPOSplat = @{Policy='Machine'}

        #Add Filter to splat table
        If($Filter){$LGPOSplat += @{Filter=$Filter}}

        #Add LGPO to splat table
        If($LGPOBinaryPath){$LGPOSplat += @{LGPOBinaryPath=$LGPOBinaryPath}}

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

        .PARAMETER Enforce
        If LGPO failed, this will set the registry item anyway

        .PARAMETER LGPOBinaryPath
        Use this to specify alternate location
        Defaults to "C:\ProgramData\LGPO\LGPO.exe". Download LGPO from https://www.microsoft.com/en-us/download/details.aspx?id=55319.

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

        [Parameter(Mandatory=$true,Position=2,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
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
        [Alias("f",'Force')]
        [switch]$Enforce,

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

        if (-not $PSBoundParameters.ContainsKey('Enforce')) {
            $Enforce = $false
        }
    }
    Process
    {
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

        #check if path exists
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
            Write-Error ("Local Policy was not set; LGPO binaries not found in path [{1}].`nDownload binaries from 'https://www.microsoft.com/en-us/download/details.aspx?id=55319' " -f ${CmdletName},$LGPOBinaryPath)
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
                Set-ItemProperty -Path $RegPath -Name $RegKeyName -Value $Value -Force -WhatIf:$WhatIfPreference -ErrorAction Stop
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
        Use this to specify alternate location
        Defaults to "C:\ProgramData\LGPO\LGPO.exe". Download LGPO from https://www.microsoft.com/en-us/download/details.aspx?id=55319.

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

        [Parameter(Mandatory=$true,Position=2,ParameterSetName="name",ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [Alias("v")]
        [string]$Name,

        [Parameter(Mandatory=$true,Position=2,ParameterSetName="all")]
        [Alias("a")]
        [switch]$AllValues,

        [Parameter(Mandatory=$false)]
        [Alias("f",'Force')]
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
        #set boolean value
        if (-not $PSBoundParameters.ContainsKey('Enforce')) {
            $Enforce = $false
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

        #check if path exists
        If(Test-Path $LGPOBinaryPath)
        {
            If($Enforce -eq $true){
                # build a unique output file
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

                #rebuild full path with hive
                $RegPath = ($RegHive +'\'+ $RegKeyPath)

                If($AllValues){
                    $VerboseMsg = ("{0} : Enforce enabled. Removing all registry keys from [{1}\{2}]" -f ${CmdletName},$RegHive,$RegKeyPath)
                    $ErrorMsg = ("{0} : Unable to remove registry keys from [{1}\{2}]. {3}" -f ${CmdletName},$RegHive,$RegKeyPath,$_.Exception.Message)
                }
                Else{
                    $VerboseMsg = ("{0} : Enforce enabled. Removing registry key [{3}] from [{1}\{2}]" -f ${CmdletName},$RegHive,$RegKeyPath,$RegKeyName)
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
            Else{

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
            }

        }
        Else{
            Write-Error ("Local Policy was not set; LGPO binaries not found in path [{1}].`nDownload binaries from 'https://www.microsoft.com/en-us/download/details.aspx?id=55319' " -f ${CmdletName},$LGPOBinaryPath)
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
        Use this to specify alternate location
        Defaults to "C:\ProgramData\LGPO\LGPO.exe". Download LGPO from https://www.microsoft.com/en-us/download/details.aspx?id=55319.

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

        .PARAMETER Name
        Required. Specify Name of registry key to set.

        .PARAMETER Type
        Default to 'DWord'. Specify type of registry item

        .PARAMETER Value
        Specify value or Key name

        .PARAMETER Enforce
        If LGPO failed, this will set the registry item anyway

        .PARAMETER LGPOBinaryPath
        Use this to specify alternate location
        Defaults to "C:\ProgramData\LGPO\LGPO.exe". Download LGPO from https://www.microsoft.com/en-us/download/details.aspx?id=55319.

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

        [Parameter(Mandatory=$true,Position=2,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
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
        [string]$ApplyTo,

        [Parameter(Mandatory=$false)]
        [Alias("f",'Force')]
        [switch]$Enforce,

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
        if (-not $PSBoundParameters.ContainsKey('Enforce')) {
            $Enforce = $false
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

        #check if hive is local machine.
        If($RegHive -match "HKEY_LOCAL_MACHINE|HKLM|HKCR"){
            Throw ("Registry path [{1}] is not a user path. Use ' Set-LocalPolicySetting' cmdlet instead" -f ${CmdletName},$RegKeyHive)
        }

        #detect if first values has hive; otherwise assume allusers
        If( -Not(Test-Path "$($RegKeyHive):" -PathType Container) ){
            $RegHive = 'HKCU'
            $RegKeyPath = $RegPath
        }

        #Break down registry to get path
        $RegKeyPath = ($RegPath).Split('\',2)[1]
        $RegKeyName = $Name
        
        #Grab user keys and profiles based on whom it will be applied to
        Switch($ApplyTo){
            'AllUsers'      {$RegHive = 'Registry::HKEY_USERS'; $ProfileList = $UserProfiles}
            'CurrentUser'   {$RegHive = 'HKCU'      ; $ProfileList = ($UserProfiles | Where-Object{$_.SID -eq $CurrentSID})}
            'DefaultUser'   {$RegHive = 'HKU'       ; $ProfileList = $DefaultProfile}
            default      {$RegHive = 'Registry::HKEY_USERS'; $ProfileList = $UserProfiles}
        }
        Write-Verbose ("Setting Registry hive from [{0}] to [{1}]" -f  $RegKeyHive,$RegHive)

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
                    Write-Verbose ("{0} : RUNNING CMDLET: Set-LocalPolicySetting -Path `"$RegHive\$($UserProfile.SID)\$RegKeyPath`" -Name $RegKeyName -Type $Type -Value $Value -LGPOBinaryPath $LGPOBinaryPath -Enforce:$Enforce -WhatIf:$WhatIfPreference" -f ${CmdletName})
                    Set-LocalPolicySetting -Path "$RegHive\$($UserProfile.SID)\$RegKeyPath" -Name $RegKeyName -Type $Type -Value $Value -LGPOBinaryPath $LGPOBinaryPath -Enforce:$Enforce -WhatIf:$WhatIfPreference
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
            Write-Verbose ("{0} : RUNNING CMDLET: Set-LocalPolicySetting -Path `"$RegHive\$RegKeyPath`" -Name $RegKeyName -Type $Type -Value $Value -LGPOBinaryPath $LGPOBinaryPath -Enforce:$Enforce -WhatIf:$WhatIfPreference" -f ${CmdletName})
            Set-LocalPolicySetting -Path "$RegHive\$RegKeyPath" -Name $RegKeyName -Type $Type -Value $Value -LGPOBinaryPath $LGPOBinaryPath -Enforce:$Enforce -WhatIf:$WhatIfPreference
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

        .PARAMETER Enforce
        If LGPO failed, this will remove the registry item anyway

        .PARAMETER LGPOBinaryPath
        Use this to specify alternate location
        Defaults to "C:\ProgramData\LGPO\LGPO.exe". Download LGPO from https://www.microsoft.com/en-us/download/details.aspx?id=55319.

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

        [Parameter(Mandatory=$false,Position=2,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [Alias("v")]
        [string]$Name,

        [Parameter(Mandatory=$false)]
        [ValidateSet('CurrentUser','AllUsers','DefaultUser')]
        [Alias("Users")]
        [string]$ApplyTo = 'AllUsers',

        [Parameter(Mandatory=$false)]
        [Alias("f",'Force')]
        [switch]$Enforce,

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
        #set boolean value
        if (-not $PSBoundParameters.ContainsKey('Enforce')) {
            $Enforce = $False
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

        #check if hive is local machine.
        If($RegHive -match "HKEY_LOCAL_MACHINE|HKLM|HKCR"){
            Throw ("Registry path [{1}] is not a user path. Use ' Set-LocalPolicySetting' cmdlet instead" -f ${CmdletName},$RegKeyHive)
        }

        #detect if first values has hive; otherwise assume allusers
        If( -Not(Test-Path "$($RegKeyHive):" -PathType Container) ){
            $RegHive = 'HKCU'
            $RegKeyPath = $RegPath
        }

        #if Name not specified, grab last value from full path
        If($PSBoundParameters.ContainsKey('Name')){
            $RegKeyPath = ($RegPath).Split('\',2)[1]
            $RegKeyName = $Name
        }
        Else{
            Write-Verbose ("Spliting path [{0}]. Assuming last item is key name" -f $RegPath)
            $RegKeyPath = Split-Path ($RegPath).Split('\',2)[1] -Parent
            $RegKeyName = ($RegPath).Split('\')[-1]
        }

        #Grab user keys and profiles based on whom it will be applied to
        Switch($ApplyTo){
            'AllUsers'      {$RegHive = 'Registry::HKEY_USERS'; $ProfileList = $UserProfiles}
            'CurrentUser'   {$RegHive = 'HKCU'      ; $ProfileList = ($UserProfiles | Where-Object{$_.SID -eq $CurrentSID})}
            'DefaultUser'   {$RegHive = 'HKU'       ; $ProfileList = $DefaultProfile}
            default      {$RegHive = 'Registry::HKEY_USERS'; $ProfileList = $UserProfiles}
        }
        Write-Verbose ("Setting Registry hive from [{0}] to [{1}]" -f  $RegKeyHive,$RegHive)

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
                    Write-Verbose ("{0} : RUNNING CMDLET: Remove-LocalPolicySetting -Path `"$RegHive\$($UserProfile.SID)\$RegKeyPath`" -Name $RegKeyName -LGPOBinaryPath $LGPOBinaryPath -Enforce:$Enforce -WhatIf:$WhatIfPreference" -f ${CmdletName})
                    Remove-LocalPolicySetting -Path "$RegHive\$($UserProfile.SID)\$RegKeyPath" -Name $RegKeyName -LGPOBinaryPath $LGPOBinaryPath -Enforce:$Enforce -WhatIf:$WhatIfPreference
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
            Write-Verbose ("{0} : RUNNING CMDLET: Remove-LocalPolicySetting -Path `"$RegHive\$RegKeyPath`" -Name $RegKeyName -LGPOBinaryPath $LGPOBinaryPath -Enforce:$Enforce -WhatIf:$WhatIfPreference" -f ${CmdletName})
            Remove-LocalPolicySetting -Path "$RegHive\$RegKeyPath" -Name $RegKeyName -LGPOBinaryPath $LGPOBinaryPath -Enforce:$Enforce -WhatIf:$WhatIfPreference
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
    Param (
        [Parameter(Mandatory=$false,Position=1)]
        [ValidateSet('Machine','Computer','User')]
        $Policy
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



function Get-IniContent{
    <#
    $value = $iniContent[“386Enh"][“EGA80WOA.FON"]
    $iniContent[“386Enh"].Keys | %{$iniContent["386Enh"][$_]}
    #>
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$True)]
        [string]$FilePath
    )
    Begin{
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Function started"
        $ini = @{}
    }
    Process{
        switch -regex -file $FilePath
        {
            "^\[(.+)\]" # Section
            {
                $section = $matches[1]
                $ini[$section] = @{}
                $CommentCount = 0
            }
            "^(;.*)$" # Comment
            {
                $value = $matches[1]
                $CommentCount = $CommentCount + 1
                $name = "Comment" + $CommentCount
                $ini[$section][$name] = $value
            }
            "(.+?)\s*=(.*)" # Key
            {
                $name,$value = $matches[1..2]
                $ini[$section][$name] = $value
            }
        }
       return $ini
    }
    End{
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"
    }
}



function Set-IniContent{
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline=$True,Mandatory=$True)]
        [Hashtable]$InputObject,

        [Parameter(Mandatory=$True)]
        [string]$FilePath,

        [ValidateSet("Unicode","UTF7","UTF8","UTF32","ASCII","BigEndianUnicode","Default","OEM")]
        [Parameter()]
        [string]$Encoding = "Unicode",

        [switch]$Force,

        [switch]$Append,

        [switch]$Passthru,

        [switch]$NewLine
    )
    Begin{
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Function started"
    }
    Process{
        if ($append) {$outfile = Get-Item $FilePath}
        else {$outFile = New-Item -ItemType file -Path $Filepath -Force:$Force -ErrorAction SilentlyContinue}
        if (!($outFile)) {Throw "Could not create File"}
        foreach ($i in $InputObject.keys){
            if (!($($InputObject[$i].GetType().Name) -eq "Hashtable")){
                #No Sections
                Write-Verbose "$($MyInvocation.MyCommand.Name):: Writing key: $i"
                Add-Content -Path $outFile -Value "$i=$($InputObject[$i])" -NoNewline -Encoding $Encoding

            }
            else {
                #Sections
                Write-Verbose "$($MyInvocation.MyCommand.Name):: Writing Section: [$i]"
                $fullList = Get-IniContent $FilePath
                $sectionFound = $fullList[$i]

                #if section [] was not found add it
                If(!$sectionFound){
                    #Add-Content -Path $outFile -Value "" -Encoding $Encoding
                    Add-Content -Path $outFile -Value "[$i]" -Encoding $Encoding
                    }

                Foreach ($j in ($InputObject[$i].keys | Sort-Object)){
                    if ($j -match "^Comment[\d]+") {
                        Write-Verbose "$($MyInvocation.MyCommand.Name):: Writing comment: $j"
                        Add-Content -Path $outFile -Value "$($InputObject[$i][$j])" -NoNewline -Encoding $Encoding
                    }
                    else {
                        Write-Verbose "$($MyInvocation.MyCommand.Name):: Writing key: $j"
                        Add-Content -Path $outFile -Value "$j=$($InputObject[$i][$j])" -NoNewline -Encoding $Encoding
                    }
                }
                If($NewLine){Add-Content -Path $outFile -Value "" -Encoding $Encoding}
            }
        }
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Finished Writing to file: $path"
        If($PassThru){Return $outFile}
    }
    End{
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"
    }
}

function Remove-IniContent{
    <#
    .SYNOPSIS
    Removes an entry/line/setting from an INI file.

    .DESCRIPTION
    A configuration file consists of sections, led by a `[section]` header and followed by `name = value` entries.  This function removes an entry in an INI file.  Something like this:

        [ui]
        username = Regina Spektor <regina@reginaspektor.com>

        [extensions]
        share =
        extdiff =

    Names are not allowed to contains the equal sign, `=`.  Values can contain any character.  The INI file is parsed using `Split-IniContent`.  [See its documentation for more examples.](Split-IniContent.html)

    If the entry doesn't exist, does nothing.
    Be default, operates on the INI file case-insensitively. If your INI is case-sensitive, use the `-CaseSensitive` switch.

    .LINK
    Set-IniEntry

    .LINK
    Split-IniContent

    .EXAMPLE
    Remove-IniEntry -Path C:\Projects\Carbon\StupidStupid.ini -Section rat -Name tails

    Removes the `tails` item in the `[rat]` section of the `C:\Projects\Carbon\StupidStupid.ini` file.

    .EXAMPLE
    Remove-IniEntry -Path C:\Users\me\npmrc -Name 'prefix' -CaseSensitive

    Demonstrates how to remove an INI entry in an INI file that is case-sensitive.
    #>

    [CmdletBinding(SupportsShouldProcess=$true)]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]
        # The path to the INI file.
        $Path,
        [string]
        # The name of the INI entry to remove.
        $Name,
        [string]
        # The section of the INI where the entry should be set.
        $Section,
        [Switch]
        # Removes INI entries in a case-sensitive manner.
        $CaseSensitive
    )

    $settings = @{ }

    if( Test-Path $Path -PathType Leaf ){
        $settings = Split-IniContent -Path $Path -AsHashtable -CaseSensitive:$CaseSensitive
    }
    else{
       Write-Error ('INI file {0} not found.' -f $Path)
        return
    }

    $key = $Name
    if( $Section ){
        $key = '{0}.{1}' -f $Section,$Name
    }

    if( $settings.ContainsKey( $key ) )
    {
        $lines = New-Object 'Collections.ArrayList'
        Get-Content -Path $Path | ForEach-Object { [void] $lines.Add( $_ ) }
        $null = $lines.RemoveAt( ($settings[$key].LineNumber - 1) )
        if( $PSCmdlet.ShouldProcess( $Path, ('remove INI entry {0}' -f $key) ) )
        {
            if( $lines ){
                $lines | Set-Content -Path $Path
            }
            else{
                Clear-Content -Path $Path
            }
        }
    }
}

Function Set-LocalPolicyUserRightsAssignment{
    <#
https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/secedit-export
https://docs.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/user-rights-assignment

    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateSet('SeAssignPrimaryTokenPrivilege',
                    'SeAuditPrivilege',
                    'SeBackupPrivilege',
                    'SeBatchLogonRight',
                    'SeChangeNotifyPrivilege',
                    'SeCreateGlobalPrivilege',
                    'SeCreatePagefilePrivilege',
                    'SeCreatePermanentPrivilege',
                    'SeCreateSymbolicLinkPrivilege',
                    'SeCreateTokenPrivilege',
                    'SeDebugPrivilege',
                    'SeDelegateSessionUserImpersonatePrivilege',
                    'SeDenyBatchLogonRight',
                    'SeDenyInteractiveLogonRight',
                    'SeDenyNetworkLogonRight',
                    'SeDenyRemoteInteractiveLogonRight',
                    'SeDenyServiceLogonRight',
                    'SeEnableDelegationPrivilege',
                    'SeImpersonatePrivilege',
                    'SeIncreaseBasePriorityPrivilege',
                    'SeIncreaseQuotaPrivilege',
                    'SeIncreaseWorkingSetPrivilege',
                    'SeInteractiveLogonRight',
                    'SeLoadDriverPrivilege',
                    'SeLockMemoryPrivilege',
                    'SeMachineAccountPrivilege',
                    'SeManageVolumePrivilege',
                    'SeNetworkLogonRight',
                    'SeProfileSingleProcessPrivilege',
                    'SeRelabelPrivilege',
                    'SeRemoteInteractiveLogonRight',
                    'SeRemoteShutdownPrivilege',
                    'SeRestorePrivilege',
                    'SeSecurityPrivilege',
                    'SeServiceLogonRight',
                    'SeShutdownPrivilege',
                    'SeSyncAgentPrivilege',
                    'SeSystemEnvironmentPrivilege',
                    'SeSystemProfilePrivilege',
                    'SeSystemtimePrivilege',
                    'SeTakeOwnershipPrivilege',
                    'SeTcbPrivilege',
                    'SeTimeZonePrivilege',
                    'SeTrustedCredManAccessPrivilege',
                    'SeUndockPrivilege'
        )]
        [array]$Privilege,

        [Parameter(Mandatory=$true,Position=1)]
        [array]$User,



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
        If(!(Test-Path $InfPath)){
            Write-Log -Message "[$InfPath] not specified or does not exist. Unable to build LGPO Template." -CustomComponent "Template" -ColorLevel 6 -NewLine -HostMsg
            exit -1
        }Else{
            #build array with content
            $GptTmplContent = Split-IniContent -Path $InfPath
        }

        #First export security policy
        Try{
            $result = Start-Process secedit -ArgumentList "/export /cfg `"$env:Temp\secedit.backup.inf`"" -RedirectStandardError "$env:Temp\secedit.backup.stderr" -RedirectStandardOutput "$env:Temp\secedit.backup.stdout" -Wait -WindowStyle Hidden -PassThru -ErrorAction Stop
            Write-Verbose ("{0} : Secedit backup ran successfully." -f ${CmdletName})
        }
        Catch{
            Throw ("Failed to backup security settings. {0}" -f $result.ExitCode)
        }
        Finally{
            $CurrentSecurityPolicy = Get-content "$env:Temp\secedit.backup.inf"
        }
    }

    Process
    {
        <# SAMPLE TESTS
        [array]$User = '*S-1-1-0','*S-1-5-20','*S-1-5-32-544','*S-1-5-32-545','*S-1-5-32-551'
        [array]$User = 'S-1-1-1','S-1-5-20'
        [array]$User = 'Everyone','NT AUTHORITY\NETWORK SERVICE'
        $name = $User[0]
        $name = $User[-1]
        #>
        $SIDSet = @()
        Foreach($name in $User)
        {
            if ($name -match 'S-\d-(?:\d+-){1,14}\d+'){
                $SID = $name.replace('*','')
                #Translate SID to User; if it doesn't translate don't add to
                $objSID = New-Object System.Security.Principal.SecurityIdentifier($SID)
                Try{
                    $UserName = ($objSID.Translate([System.Security.Principal.NTAccount])).Value
                    Write-Verbose ("{0} : Translated user [{1}] to User [{2}]." -f ${CmdletName},$SID,$UserName)
                }
                Catch{
                    Write-Verbose ("{0} : Error with SID [{1}]. {2}" -f ${CmdletName},$SID,$_.Exception.Message)
                    Continue
                }
            }
            else{
                $UserName = $User
                #Translate User to SID
                Try{
                    $SID = ((New-Object System.Security.Principal.NTAccount($name)).Translate([System.Security.Principal.SecurityIdentifier])).Value
                    Write-Verbose ("{0} : Translated user [{1}] to SID [{2}]." -f ${CmdletName},$UserName,$SID)
                }
                Catch{
                    Write-Verbose ("{0} : Unable to get SID from [{1}]. {2}" -f ${CmdletName},$UserName,$_.Exception.Message)
                    Continue
                }
            }
            $SID = '*' + $SID
            $SIDSet += $SID
        }
        $NewUsers = $SIDSet -join ','

        <# SAMPLE TESTS
        [array]$Privilege = 'SeNetworkLogonRight','SeBackupPrivilege'

        $Right = $Privilege[0]
        #>
        #$MatchPrivilege = $Privilege -join '|'

        Foreach($Right in $Privilege)
        {
            $NewRights = $Right + " = " + $NewUsers
            If($ExistingRights = ($CurrentSecurityPolicy | Select-String -Pattern $Right).Line)
            {
                $RightsToReplace = $ExistingRights
                $CurrentSecurityPolicy = $CurrentSecurityPolicy.replace($RightsToReplace,$NewRights)
            }
            Else{

            }


        }
        $CurrentSecurityPolicy | Set-Content "$env:Temp\secedit.updated.inf"

        <#
        #generate start of file
        $secedit =  "[Unicode]`r`n"
        $secedit += "Unicode=yes`r`n"
        $secedit += "[Version]`r`n"
        $secedit += "signature=`"`$CHICAGO`$`"`r`n"
        $secedit += "Revision=1`r`n"
        #>



        #get system access section
        If (($GptTmplContent.Section -eq 'System Access').count -gt 0){
            $SystemAccessFound = $true
            Write-host "'System Access' section found in [$InfPath], building list...." -ForegroundColor Cyan
            $secedit += "[System Access]`r`n"

            $AccessValueList = $GptTmplContent | Where {$_.section -eq 'System Access'}
            Foreach ($AccessKey in $AccessValueList){
                $AccessName = $AccessKey.Name
                $AccessValue = $AccessKey.Value
                If ($AccessName -eq "NewAdministratorName"){
                    $AccessValue = $AccessValue -replace $AccessKey.Value, "$Global:NewAdministratorName"
                }
                If ($AccessName -eq "NewGuestName"){
                    $AccessValue = $AccessValue -replace $AccessKey.Value, "$Global:NewGuestName"
                }
                $secedit += "$AccessName = $AccessValue`r`n"
                #$secedit += "$PrivilegeValue"
            }
        }
        Else{
            $SystemAccessFound = $false
            Write-host "'System Access' section was not found in [$InfPath], skipping..." -ForegroundColor Gray
        }

        #next get Privilege Rights section
        If (($GptTmplContent.Section -eq 'Privilege Rights').count -gt 0){
            $PrivilegeRightsFound = $true
            Write-host "'Privilege Rights' section found in [$InfPath], building list...." -ForegroundColor Cyan
            $secedit += "[Privilege Rights]`r`n"

            $PrivilegeValueList = $GptTmplContent | Where {$_.section -eq 'Privilege Rights'}
            Foreach ($PrivilegeKey in $PrivilegeValueList){
                $PrivilegeName = $PrivilegeKey.Name
                $PrivilegeValue = $PrivilegeKey.Value

                If ($PrivilegeValue -match "ADD YOUR ENTERPRISE ADMINS|ADD YOUR DOMAIN ADMINS|S-1-5-21"){

                    If($IsMachinePartOfDomain){
                        $EA_SID = Get-UserToSid -Domain $envMachineDNSDomain -User "Enterprise Admins"
                        $DA_SID = Get-UserToSid -Domain $envMachineDNSDomain -User "Domain Admins"
                        $PrivilegeValue = $PrivilegeValue -replace "ADD YOUR ENTERPRISE ADMINS",$EA_SID
                        $PrivilegeValue = $PrivilegeValue -replace "ADD YOUR DOMAIN ADMINS",$DA_SID
                    }
                    Else{
                        $ADMIN_SID = Get-UserToSid -LocalAccount 'Administrators'
                        $PrivilegeValue = $PrivilegeValue -replace "ADD YOUR ENTERPRISE ADMINS",$ADMIN_SID
                        $PrivilegeValue = $PrivilegeValue -replace "ADD YOUR DOMAIN ADMINS",$ADMIN_SID
                        $PrivilegeValue = $PrivilegeValue -replace "S-1-5-21-[0-9-]+",$ADMIN_SID
                    }
                }
                #split up values, get only unique values and make it a comma deliminated list again
                $temp = $PrivilegeValue -split ","
                $PrivilegeValue = $($temp | Get-Unique) -join ","


                $secedit += "$PrivilegeName = $PrivilegeValue`r`n"
                #$secedit += "$PrivilegeValue"

                #Write-Log -Message "RUNNING COMMAND: SECEDIT /configure /db secedit.sdb /cfg '$workingTempPath\$($GPO.name).seceditapply.inf' /overwrite /log '$workingLogPath\$($GPO.name).seceditapply.log' /quiet" -CustomComponent "COMMAND" -ColorLevel 8 -NewLine None -HostMsg
                #Start-Process SECEDIT -ArgumentList " /configure /db secedit.sdb /cfg ""$workingTempPath\$($GPO.name).seceditapply.inf"" /overwrite /quiet" -RedirectStandardOutput "$workingLogPath\$($GPO.name).secedit.stdout.log" -RedirectStandardError "$workingLogPath\$($GPO.name).secedit.stderr.log" -Wait -NoNewWindow
                #$SeceditApplyResults = ECHO y| SECEDIT /configure /db secedit.sdb /cfg "$workingTempPath\$($GPO.name).seceditapply.inf" /overwrite /log "$workingLogPath\$($GPO.name).seceditapply.log"
            }
        }
        Else{
            $PrivilegeRightsFound = $false
            Write-host "'Privilege Rights' was not found in [$InfPath], skipping..." -ForegroundColor Gray
        }


    }
    End {
        If($secedit){
            $secedit | Out-File "$env:Temp\$OutputName" -Force
            Write-host "Saved file to [$env:Temp\$OutputName]" -ForegroundColor Gray
        }
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
