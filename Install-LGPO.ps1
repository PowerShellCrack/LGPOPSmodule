#=======================================================
# VARIABLES
#=======================================================
$LocalLGPOpath = "$Env:ALLUSERSPROFILE\LGPO"
$LGPOURI = 'https://download.microsoft.com/download/8/5/C/85C25433-A1B0-4FFA-9429-7E023E7DA8D8/LGPO.zip'


##*=============================================
##* Runtime Function - REQUIRED
##*=============================================

#region FUNCTION: Check if running in ISE
Function Test-IsISE {
    # trycatch accounts for:
    # Set-StrictMode -Version latest
    try {
        return ($null -ne $psISE);
    }
    catch {
        return $false;
    }
}
#endregion

#region FUNCTION: Check if running in Visual Studio Code
Function Test-VSCode{
    if($env:TERM_PROGRAM -eq 'vscode') {
        return $true;
    }
    Else{
        return $false;
    }
}
#endregion

#region FUNCTION: Find script path for either ISE or console
Function Get-ScriptPath {
    <#
        .SYNOPSIS
            Finds the current script path even in ISE or VSC
        .LINK
            Test-VSCode
            Test-IsISE
    #>
    param(
        [switch]$Parent
    )

    Begin{}
    Process{
        Try{
            if ($PSScriptRoot -eq "")
            {
                if (Test-IsISE)
                {
                    $ScriptPath = $psISE.CurrentFile.FullPath
                }
                elseif(Test-VSCode){
                    $context = $psEditor.GetEditorContext()
                    $ScriptPath = $context.CurrentFile.Path
                }Else{
                    $ScriptPath = (Get-location).Path
                }
            }
            else
            {
                $ScriptPath = $PSCommandPath
            }
        }
        Catch{
            $ScriptPath = '.'
        }
    }
    End{

        If($Parent){
            Split-Path $ScriptPath -Parent
        }Else{
            $ScriptPath
        }
    }

}
#endregion

Function Write-LogEntry{
    <#
    .SYNOPSIS
        Creates a log file

    .DESCRIPTION
       Creates a log file format for cmtrace log reader

    .NOTES
        Allows to view log using cmtrace while being written to

    .PARAMETER Message
        Write message to log file

    .PARAMETER Source
        Defaults to the script running or another function that calls this function.
        Used to specify a different source if specified

    .PARAMETER Severity
        Ranges 1-5. CMtrace will highlight severity 2 as yellow and 3 as red.
        If Passthru parameter used will change host output:
        0 = Green
        1 = Gray
        2 = Yellow
        3 = Red
        4 = Verbose Output
        5 = Debug output

    .PARAMETER OutputLogFile
        Defaults to $Global:LogFilePath. Specify location of log file.

    .PARAMETER Passthru
        Output message to host as well. Great when replacing Write-Host with Write-LogEntry

    .EXAMPLE
        #build global log fullpath
        $Global:LogFilePath = "$env:Windir\Logs\$($scriptName)_$(Get-Date -Format 'yyyy-MM-dd_Thh-mm-ss-tt').log"
        Write-LogEntry -Message 'this is a new message' -Severity 1 -Passthru

    .EXAMPLE
        Function Test-output{
            ${CmdletName} = $MyInvocation.InvocationName
            Write-LogEntry -Message ('this is a new message from [{0}]' -f $MyInvocation.InvocationName) -Source ${CmdletName} -Severity 0 -Passthru
        }
        Test-output

        OUTPUT is in green:
        [21:07:50.476-300] [Test-output] :: this is a new message from [Test-output]

    .EXAMPLE
        Create entry in log with warning message and output to host in yellow
        Write-LogEntry -Message 'this is a log entry from an error' -Severity 2 -Passthru

    .EXAMPLE
        Create entry in log with error and output to host in red
        Write-LogEntry -Message 'this is a log entry from an error' -Severity 3 -Passthru

    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(Mandatory=$false,Position=1)]
		[string]$Source,

        [parameter(Mandatory=$false,Position=2)]
        [ValidateSet(0,1,2,3,4,5)]
        [int16]$Severity,

        [parameter(Mandatory=$false, HelpMessage="Name of the log file that the entry will written to.")]
        [ValidateNotNullOrEmpty()]
        [string]$OutputLogFile = $Global:LogFilePath,

        [parameter(Mandatory=$false)]
        [switch]$Passthru
    )

    #get BIAS time
    [string]$LogTime = (Get-Date -Format 'HH:mm:ss.fff').ToString()
	[string]$LogDate = (Get-Date -Format 'MM-dd-yyyy').ToString()
	[int32]$script:LogTimeZoneBias = [timezone]::CurrentTimeZone.GetUtcOffset([datetime]::Now).TotalMinutes
	[string]$LogTimePlusBias = $LogTime + $script:LogTimeZoneBias

    #  Get the file name of the source script
    If($Source){
        [string]$ScriptSource = $Source
    }
    Else{
        Try {
    	    If($MyInvocation.InvocationName){
                [string]$ScriptSource = $MyInvocation.InvocationName
            }
            ElseIf ($script:MyInvocation.Value.ScriptName) {
    		    [string]$ScriptSource = Split-Path -Path $script:MyInvocation.Value.ScriptName -Leaf -ErrorAction 'Stop'
    	    }
    	    Else {
    		    [string]$ScriptSource = Split-Path -Path $script:MyInvocation.MyCommand.Definition -Leaf -ErrorAction 'Stop'
    	    }
        }
        Catch {
    	    [string]$ScriptSource = ''
        }
    }

    #if the severity and preference level not set to silentlycontinue, then log the message
    $LogMsg = $true
    If( $Severity -eq 4 ){$Message='VERBOSE: ' + $Message;If(!$VerboseEnabled){$LogMsg = $false} }
    If( $Severity -eq 5 ){$Message='DEBUG: ' + $Message;If(!$DebugEnabled){$LogMsg = $false} }
    #If( ($Severity -eq 4) -and ($VerbosePreference -eq 'SilentlyContinue') ){$LogMsg = $false$Message='VERBOSE: ' + $Message}
    #If( ($Severity -eq 5) -and ($DebugPreference -eq 'SilentlyContinue') ){$LogMsg = $false;$Message='DEBUG: ' + $Message}

    #generate CMTrace log format
    $LogFormat = "<![LOG[$Message]LOG]!>" + "<time=`"$LogTimePlusBias`" " + "date=`"$LogDate`" " + "component=`"$ScriptSource`" " + "context=`"$([Security.Principal.WindowsIdentity]::GetCurrent().Name)`" " + "type=`"$Severity`" " + "thread=`"$PID`" " + "file=`"$ScriptSource`">"

    # Add value to log file
    If($LogMsg)
    {
        try {
            Out-File -InputObject $LogFormat -Append -NoClobber -Encoding Default -FilePath $OutputLogFile -ErrorAction Stop
        }
        catch {
            Write-Host ("[{0}] [{1}] :: Unable to append log entry to [{1}], error: {2}" -f $LogTimePlusBias,$ScriptSource,$OutputLogFile,$_.Exception.ErrorMessage) -ForegroundColor Red
        }
    }

    #output the message to host
    If($Passthru)
    {
        If($Source){
            $OutputMsg = ("[{0}] [{1}] :: {2}" -f $LogTimePlusBias,$Source,$Message)
        }
        Else{
            $OutputMsg = ("[{0}] [{1}] :: {2}" -f $LogTimePlusBias,$ScriptSource,$Message)
        }

        Switch($Severity){
            0       {Write-Host $OutputMsg -ForegroundColor Green}
            1       {Write-Host $OutputMsg -ForegroundColor Gray}
            2       {Write-Host $OutputMsg -ForegroundColor Yellow}
            3       {Write-Host $OutputMsg -ForegroundColor Red}
            4       {Write-Verbose $OutputMsg}
            5       {Write-Debug $OutputMsg}
            default {Write-Host $OutputMsg}
        }
    }
}
##*========================================================================
##* VARIABLE DECLARATION
##*========================================================================
#region VARIABLES: Building paths & values
# Use function to get paths because Powershell ISE & other editors have differnt results
[string]$scriptPath = Get-ScriptPath
[string]$scriptName = [IO.Path]::GetFileNameWithoutExtension($scriptPath)

#specify path of log
$Global:LogFilePath = "$env:Windir\Logs\$($scriptName)_$(Get-Date -Format 'yyyy-MM-dd_Thh-mm-ss-tt').log"

#=======================================================
# MAIN
#=======================================================
#Test/Create Temp Directory
if((Test-Path $LocalLGPOpath) -eq $false) {
    Write-LogEntry -Message ('Creating LGPO directory [{0}]' -f $LocalLGPOpath) -Passthru
    New-Item -Path $LocalLGPOpath -ItemType Directory -Force -ErrorAction SilentlyContinue
}

# Download FSlogix
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Write-LogEntry -Message ('Downloading FSLogix from URL [{0}]' -f $LGPOURI) -Passthru
Invoke-WebRequest -Uri $LGPOURI -OutFile "$LocalLGPOpath\LGPO.zip"

# Extract FSLogix Files
Write-LogEntry -Message ('Unzipping LGPO file [{0}]' -f "$LocalLGPOpath\LGPO.zip") -Passthru
Expand-Archive -LiteralPath "$LocalLGPOpath\LGPO.zip" -DestinationPath $LocalLGPOpath -Force -Verbose

#prepare Directory
$LGPOFile = Get-ChildItem $LocalLGPOpath -Recurse -Filter LGPO.exe
$LGPOFile | Move-Item -Destination $LocalLGPOpath -Force
Remove-Item "$LocalLGPOpath\LGPO.zip" -Force -ErrorAction SilentlyContinue

Write-LogEntry -Message ('Install LGPO module') -Passthru
Install-Module LGPO -Force -ErrorAction SilentlyContinue

Write-LogEntry -Message ('Completed LGPO install') -Passthru
