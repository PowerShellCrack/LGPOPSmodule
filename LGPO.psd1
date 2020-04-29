@{

# Script module or binary module file associated with this manifest.
ModuleToProcess = 'LGPO.psm1'

# Version number of this module.
ModuleVersion = '1.0.0.0'

# ID used to uniquely identify this module
GUID = '1e46bbf8-1927-4149-99cf-fd765060740d'

# Author of this module
Author = 'Dick Tracy'

# Copyright statement for this module
Copyright = '(c) 2018-2020 Powershellcrack'

# Description of the functionality provided by this module
Description = 'Converts registry items into local secureity policy using LGPO'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '3.0'

# Functions to export from this module
FunctionsToExport = @(
    'Set-SystemSetting',
    'Set-UserSettinge'
)

# Cmdlets to export from this module
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = @()

# Aliases to export from this module
#AliasesToExport = @('??')

# Private data to pass to the module specified in RootModule/ModuleToProcess.
# This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{
        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @('lgpo', 'registry', 'security-policy')

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/PowerShellCrack/LGPOPSmodule/LICENSE.txt'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/PowerShellCrack/LGPOPSmodule'

        # ReleaseNotes of this module
        ReleaseNotes = 'https://github.com/PowerShellCrack/LGPOPSmodule/CHANGELOG.md'
    }

}

}
