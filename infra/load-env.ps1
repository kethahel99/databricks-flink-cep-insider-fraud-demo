#Requires -Version 5.1

<#
.SYNOPSIS
    Loads environment variables from a .env file into the current PowerShell session.

.DESCRIPTION
    This script reads a .env file and sets the environment variables in the current
    PowerShell session. It supports both simple KEY=VALUE format and quoted values.

.PARAMETER EnvFilePath
    Path to the .env file. Defaults to ".env" in the current directory.

.PARAMETER ProjectRoot
    Path to the project root directory. Defaults to the parent directory of the script location.

.EXAMPLE
    # Load .env from current directory
    .\load-env.ps1

.EXAMPLE
    # Load specific .env file
    .\load-env.ps1 -EnvFilePath "C:\path\to\.env"

.EXAMPLE
    # Load .env from specific project root
    .\load-env.ps1 -ProjectRoot "C:\my\project"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$EnvFilePath,

    [Parameter(Mandatory=$false)]
    [string]$ProjectRoot
)

# Determine project root
if (-not $ProjectRoot) {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
}

# Determine .env file path
if (-not $EnvFilePath) {
    $EnvFilePath = Join-Path $ProjectRoot ".env"
}

# Check if .env file exists
if (-not (Test-Path $EnvFilePath)) {
    Write-Warning "Environment file not found: $EnvFilePath"
    Write-Host "Please ensure the .env file exists and contains your environment variables."
    Write-Host "You can copy from .env.sample: cp .env.sample .env"
    exit 1
}

Write-Host "Loading environment variables from: $EnvFilePath"

# Read and parse the .env file
$envContent = Get-Content $EnvFilePath -Encoding UTF8

$loadedVars = 0
foreach ($line in $envContent) {
    # Skip empty lines and comments
    $line = $line.Trim()
    if ([string]::IsNullOrEmpty($line) -or $line.StartsWith('#')) {
        continue
    }

    # Parse KEY=VALUE format
    if ($line -match '^([^=]+)=(.*)$') {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim()

        # Remove surrounding quotes if present
        if ($value.StartsWith('"') -and $value.EndsWith('"')) {
            $value = $value.Substring(1, $value.Length - 2)
        } elseif ($value.StartsWith("'") -and $value.EndsWith("'")) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        # Set the environment variable
        [Environment]::SetEnvironmentVariable($key, $value, "Process")
        $loadedVars++

        Write-Host "  $key = $value"
    } else {
        Write-Warning "Skipping invalid line: $line"
    }
}

Write-Host "`nLoaded $loadedVars environment variables."
Write-Host "These variables are now available in the current PowerShell session."

# Display usage example
Write-Host "`nExample usage:"
Write-Host "  `$env:SUBSCRIPTION_ID"
Write-Host "  `$env:RESOURCE_GROUP"
Write-Host "  `$env:LOCATION"