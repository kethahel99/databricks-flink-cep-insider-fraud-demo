#!/usr/bin/env bash
# Load environment variables from .env file and launch PowerShell

set -euo pipefail

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default .env file path
ENV_FILE="${1:-$PROJECT_ROOT/.env}"

# Check if .env file exists
if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: Environment file not found: $ENV_FILE"
    echo "Please ensure the .env file exists and contains your environment variables."
    echo "You can copy from .env.sample: cp .env.sample .env"
    exit 1
fi

echo "Loading environment variables from: $ENV_FILE"

# Function to export variables for PowerShell
export_vars() {
    local env_file="$1"

    # Read .env file and export variables
    while IFS='=' read -r key value; do
        # Skip empty lines and comments
        [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue

        # Remove surrounding whitespace
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # Remove surrounding quotes if present
        if [[ "$value" =~ ^\".*\"$ ]]; then
            value="${value:1:-1}"
        elif [[ "$value" =~ ^\'.*\'$ ]]; then
            value="${value:1:-1}"
        fi

        # Export the variable
        export "$key=$value"
        echo "  $key = $value"

    done < "$env_file"
}

# Load the variables
LOADED_VARS=$(export_vars "$ENV_FILE" | wc -l)
echo "Loaded $((LOADED_VARS - 1)) environment variables."

# Launch PowerShell with the environment variables
echo "Launching PowerShell with loaded environment variables..."
echo "You can now use these variables in PowerShell as \$env:VARIABLE_NAME"
echo ""

# Check if pwsh is available
if command -v pwsh >/dev/null 2>&1; then
    exec pwsh -NoExit -Command "Write-Host 'Environment variables loaded. You can now run: .\deploy.ps1'"
else
    echo "Error: PowerShell Core (pwsh) is not installed."
    echo "Please install it first:"
    echo "  Ubuntu/Debian: sudo apt-get install -y powershell"
    echo "  Or download from: https://github.com/PowerShell/PowerShell/releases"
    exit 1
fi