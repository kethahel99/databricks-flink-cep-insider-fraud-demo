#Requires -Version 5.1

param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$false)]
    [string]$Location,

    [Parameter(Mandatory=$false)]
    [string]$Prefix,

    [Parameter(Mandatory=$false)]
    [int]$AksNodeCount = 2,

    [Parameter(Mandatory=$false)]
    [string]$AksNodeSize = "Standard_D4s_v5",

    [Parameter(Mandatory=$false)]
    [string]$AcrSku = "Standard",

    [Parameter(Mandatory=$false)]
    [int]$EhCapacity = 2,

    [Parameter(Mandatory=$false)]
    [int]$EhPartitions = 12,

    [Parameter(Mandatory=$false)]
    [string]$DbxSku = "premium"
)

$ErrorActionPreference = "Stop"

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Split-Path -Parent $Here

# Load env - First check environment variables, then fall back to .env file
$EnvFile = Join-Path $Root ".env"
$envLoaded = $false

# Function to load from .env file
function Load-FromEnvFile {
    param([string]$filePath)

    if (Test-Path $filePath) {
        Get-Content $filePath | ForEach-Object {
            if ($_ -match '^([^=]+)=(.*)$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()

                # Remove surrounding quotes if present
                if ($value.StartsWith('"') -and $value.EndsWith('"')) {
                    $value = $value.Substring(1, $value.Length - 2)
                } elseif ($value.StartsWith("'") -and $value.EndsWith("'")) {
                    $value = $value.Substring(1, $value.Length - 2)
                }

                # Set as script variable if not already set from environment
                if (-not (Get-Variable -Name $key -Scope Script -ErrorAction SilentlyContinue)) {
                    Set-Variable -Name $key -Value $value -Scope Script
                }
            }
        }
        return $true
    }
    return $false
}

# Try to load from environment variables first
Write-Host "Checking for environment variables..."

# Check required variables from environment or parameters
if (-not $SubscriptionId) {
    if ($env:SUBSCRIPTION_ID) {
        $SubscriptionId = $env:SUBSCRIPTION_ID
        Write-Host "  Using SUBSCRIPTION_ID from environment"
    } elseif ((Test-Path variable:SUBSCRIPTION_ID) -and $SUBSCRIPTION_ID) {
        $SubscriptionId = $SUBSCRIPTION_ID
        Write-Host "  Using SUBSCRIPTION_ID from script variable"
    }
}

if (-not $ResourceGroup) {
    if ($env:RESOURCE_GROUP) {
        $ResourceGroup = $env:RESOURCE_GROUP
        Write-Host "  Using RESOURCE_GROUP from environment"
    } elseif ((Test-Path variable:RESOURCE_GROUP) -and $RESOURCE_GROUP) {
        $ResourceGroup = $RESOURCE_GROUP
        Write-Host "  Using RESOURCE_GROUP from script variable"
    }
}

if (-not $Location) {
    if ($env:LOCATION) {
        $Location = $env:LOCATION
        Write-Host "  Using LOCATION from environment"
    } elseif ((Test-Path variable:LOCATION) -and $LOCATION) {
        $Location = $LOCATION
        Write-Host "  Using LOCATION from script variable"
    }
}

if (-not $Prefix) {
    if ($env:PREFIX) {
        $Prefix = $env:PREFIX
        Write-Host "  Using PREFIX from environment"
    } elseif ((Test-Path variable:PREFIX) -and $PREFIX) {
        $Prefix = $PREFIX
        Write-Host "  Using PREFIX from script variable"
    }
}

# Load additional variables from environment or .env file
$additionalVars = @(
    @{Name = 'AKS_NODE_COUNT'; Default = 2; Type = 'int'},
    @{Name = 'AKS_NODE_SIZE'; Default = 'Standard_D4s_v5'; Type = 'string'},
    @{Name = 'ACR_SKU'; Default = 'Standard'; Type = 'string'},
    @{Name = 'EH_CAPACITY'; Default = 2; Type = 'int'},
    @{Name = 'EH_PARTITIONS'; Default = 12; Type = 'int'},
    @{Name = 'DBX_SKU'; Default = 'premium'; Type = 'string'}
)

foreach ($var in $additionalVars) {
    $varName = $var.Name
    $envVarName = $varName
    $scriptVarName = $varName.Replace('_', '')

    # Check environment variable
    if ($env[$envVarName]) {
        $value = $env[$envVarName]
        Write-Host "  Using $varName from environment: $value"
    }
    # Check script variable
    elseif ((Test-Path variable:$scriptVarName) -and (Get-Variable -Name $scriptVarName -Scope Script -ValueOnly)) {
        $value = Get-Variable -Name $scriptVarName -Scope Script -ValueOnly
        Write-Host "  Using $varName from script variable: $value"
    }
    else {
        $value = $var.Default
        Write-Host "  Using $varName default: $value"
    }

    # Convert to appropriate type and set parameter if not already set
    if ($var.Type -eq 'int') {
        $value = [int]$value
    }

    # Set the parameter variable if not already set
    $paramVar = Get-Variable -Name $scriptVarName -Scope Local -ErrorAction SilentlyContinue
    if (-not $paramVar -or -not $paramVar.Value) {
        Set-Variable -Name $scriptVarName -Value $value -Scope Local
    }
}

# Load from .env file as fallback
if (Load-FromEnvFile $EnvFile) {
    Write-Host "Loaded additional variables from .env file"
} else {
    Write-Host "No .env file found, using defaults and provided values"
}

# Check required variables
if (-not $SubscriptionId -or -not $ResourceGroup -or -not $Location -or -not $Prefix) {
    Write-Error "Missing required environment variables: SUBSCRIPTION_ID, RESOURCE_GROUP, LOCATION, PREFIX"
    Write-Host "Please set these variables using one of the following methods:"
    Write-Host "1. Run .\load-env.ps1 first to load from .env file"
    Write-Host "2. Set environment variables: `$env:SUBSCRIPTION_ID = 'your-value'`"
    Write-Host "3. Pass as parameters: .\deploy.ps1 -SubscriptionId 'your-value'`"
    exit 1
}

# Set Azure subscription
az account set -s $SubscriptionId

# Create resource group
az group create -n $ResourceGroup -l $Location | Out-Null

Write-Host "Deploying infra (AKS, ACR, ADLS, Event Hubs, Databricks)…"

# Deploy Bicep template
$BicepFile = Join-Path $Here "main.bicep"
$OutFile = Join-Path $Here "out.json"

az deployment group create `
  -g $ResourceGroup `
  -f $BicepFile `
  -p namePrefix=$Prefix location=$Location `
     aksNodeCount=$AksNodeCount aksNodeSize=$AksNodeSize acrSku=$AcrSku `
     dbxSku=$DbxSku ehCapacity=$EhCapacity ehPartitions=$EhPartitions `
  -o json > $OutFile

# Parse JSON output
$DeploymentOutput = Get-Content $OutFile | ConvertFrom-Json
$Outputs = $DeploymentOutput.properties.outputs

$AKS_NAME = $Outputs.aksNameOut.value
$ACR_NAME = $Outputs.acrNameOut.value
$ACR_LOGIN_SERVER = $Outputs.acrLoginServer.value
$DBX_NAME = $Outputs.databricksWorkspace.value
$SA_NAME = $Outputs.saNameOut.value
$EH_BROKER = $Outputs.eventHubsKafkaBroker.value
$EH_NS = $Outputs.eventHubsNamespace.value
$EH_SEND = $Outputs.sendConn.value
$EH_LISTEN = $Outputs.listenConn.value

# Create output environment file
$OutEnvFile = Join-Path $Root ".out.env"
$OutEnvContent = @"
AKS_NAME=$AKS_NAME
ACR_NAME=$ACR_NAME
ACR_LOGIN_SERVER=$ACR_LOGIN_SERVER
DBX_NAME=$DBX_NAME
SA_NAME=$SA_NAME
EH_BROKER=$EH_BROKER
EH_NS=$EH_NS
EH_SEND='$EH_SEND'
EH_LISTEN='$EH_LISTEN'
RESOURCE_GROUP=$ResourceGroup
LOCATION=$Location
PREFIX=$Prefix
"@

Set-Content -Path $OutEnvFile -Value $OutEnvContent

Write-Host "Outputs → $OutEnvFile"

Write-Host "Getting AKS credentials…"
az aks get-credentials -g $ResourceGroup -n $AKS_NAME --overwrite-existing

# Flink Operator (Helm)
helm repo add flink-operator https://downloads.apache.org/flink/flink-kubernetes-operator-1.10.0/ | Out-Null
helm repo update | Out-Null
helm upgrade --install flink-operator flink-operator/flink-kubernetes-operator `
  --namespace flink --create-namespace

Write-Host "Done. AKS=$AKS_NAME, ACR=$ACR_NAME ($ACR_LOGIN_SERVER), EH NS=$EH_NS"