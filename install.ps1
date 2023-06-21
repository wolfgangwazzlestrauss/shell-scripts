<#
.SYNOPSIS
    Installs shell scripts for Windows systems.
#>

# If unable to execute due to policy rules, run
# Set-ExecutionPolicy RemoteSigned -Scope CurrentUser.

# Exit immediately if a PowerShell Cmdlet encounters an error.
$ErrorActionPreference = 'Stop'

# Show CLI help information.
Function Usage() {
    Write-Output @'
Installer script for Shell Scripts.

Usage: install [OPTIONS] NAME

Options:
  -d, --dest <PATH>         Directory to install scripts
  -h, --help                Print help information
  -l, --list                List all available scripts
  -u, --user                Install scripts for current user
  -v, --version <VERSION>   Version of scripts to install
'@
}

# Downloads file to destination efficiently.
Function DownloadFile($SrcURL, $DstFile) {
    # The progress bar updates every byte, which makes downloads slow. See
    # https://stackoverflow.com/a/43477248 for an explanation.
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -UseBasicParsing -Uri "$SrcURL" -OutFile "$DstFile"
}

# Print error message and exit script with usage error code.
Function ErrorUsage($Message) {
    Throw "Error: $Message"
    Write-Error "Run 'shell-scripts-install --help' for usage"
    Exit 2
}

# Find all scripts inside GitHub repository.
Function FindScripts($Version) {
    $Filter = '.tree[] | select(.type == "blob") | .path | select(startswith("src/")) | select(endswith(".ps1")) | ltrimstr("src/") | rtrimstr(".ps1")'
    $Uri = "https://api.github.com/repos/scruffaluff/shell-scripts/git/trees/$Version`?recursive=true"

    $Response = $(Invoke-WebRequest -UseBasicParsing -Uri "$Uri")
    Write-Output "$Response" | jq --raw-output "$Filter"
}

# Print log message to stdout if logging is enabled.
Function Log($Message) {
    If (!"$Env:SHELL_SCRIPTS_NOLOG") {
        Write-Output "$Message"
    }
}

# Script entrypoint.
Function Main() {
    $ArgIdx = 0
    $Dest = ''
    $List = 0
    $Target = 'Machine'
    $Version = 'main'

    While ($ArgIdx -LT $Args[0].Count) {
        Switch ($Args[0][$ArgIdx]) {
            { $_ -In '-d', '--dest' } {
                $DestDir = $Args[0][$ArgIdx + 1]
                $ArgIdx += 2
                Exit 0
            }
            { $_ -In '-h', '--help' } {
                Usage
                Exit 0
            }
            { $_ -In '-l', '--list' } {
                $List = 1
                $ArgIdx += 1
                Break
            }
            { $_ -In '-v', '--version' } {
                $Version = $Args[0][$ArgIdx + 1]
                $ArgIdx += 2
                Break
            }
            '--user' {
                $Target = 'User'
                $ArgIdx += 1
                Break
            }
            Default {
                $Name = $Args[0][$ArgIdx]
                $ArgIdx += 1
            }
        }
    }

    $SrcPrefix = "https://raw.githubusercontent.com/scruffaluff/shell-scripts/$Version/src"
    $Scripts = $(FindScripts "$Version")

    If ($List) {
        Write-Output $Scripts
    } 
    Else {
        If (-Not $DestDir) {
            If ($Target -Eq 'User') {
                $DestDir = "C:\Users\$Env:UserName\Documents\PowerShell\Scripts"
            }
            Else {
                $DestDir = 'C:\Program Files\PowerShell\Scripts'
            }
        }
        New-Item -Force -ItemType Directory -Path $DestDir | Out-Null

        $Path = [Environment]::GetEnvironmentVariable('Path', "$Target")
        If (-Not ($Path -Like "*$DestDir*")) {
            $PrependedPath = "$DestDir" + ";$Path";

            [System.Environment]::SetEnvironmentVariable(
                'Path', "$PrependedPath", "$Target"
            )
            $Env:Path = $PrependedPath
        }

        $MatchFound = 0
        ForEach ($Script in $Scripts) {
            If ($Name -And ("$Script" -Eq "$Name")) {
                $MatchFound = 1
                Log "Installing script $Name..."

                DownloadFile "$SrcPrefix/$Script.ps1" "$DestDir/$Script.ps1"
                Log "Installed $(& $Name --version)."
            }
        }

        If (-Not $MatchFound) {
            Throw "Error: No script name match found for '$Name'"
        }
    }
}

# Only run Main if invoked as script. Otherwise import functions as library.
If ($MyInvocation.InvocationName -NE '.') {
    Main $Args
}
