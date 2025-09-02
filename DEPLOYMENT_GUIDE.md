# Azure Infrastructure Deployment Guide

This guide explains how to deploy the Databricks-Flink CEP Insider Fraud Demo infrastructure using PowerShell.

## Prerequisites

Before running the deployment script, ensure you have the following tools installed:

- **Azure CLI** (`az`) - for Azure resource management
- **PowerShell Core** (`pwsh`) - for running the deployment script
- **Helm** - for installing the Flink Kubernetes operator
- **kubectl** - for Kubernetes cluster management

## Setup Environment Variables

1. **Copy the sample environment file:**
   ```bash
   cp .env.sample .env
   ```

2. **Edit the `.env` file** with your actual Azure values:
   ```bash
   # --- Fill me --
   SUBSCRIPTION_ID=00000000-0000-0000-0000-000000000000  # Your Azure subscription ID
   RESOURCE_GROUP=rg-fraud-insider                      # Your resource group name
   LOCATION=eastus                                       # Azure region (e.g., eastus, westus2)
   PREFIX=finrt                                          # Unique prefix for resource names

   # Optional: Customize infrastructure settings
   AKS_NODE_COUNT=2                                      # Number of AKS nodes
   AKS_NODE_SIZE=Standard_D4s_v5                        # AKS node VM size
   ACR_SKU=Standard                                     # Azure Container Registry SKU
   EH_CAPACITY=2                                         # Event Hubs capacity units
   EH_PARTITIONS=12                                      # Event Hubs partitions
   DBX_SKU=premium                                       # Databricks workspace SKU
   ```

### Environment Variable Loader Scripts

Two helper scripts are provided to automatically load environment variables:

#### Option A: PowerShell Script (Recommended)
```bash
cd infra
pwsh ./load-env.ps1
```
This loads variables directly into your PowerShell session.

#### Option B: Bash Script
```bash
cd infra
./load-env.sh
```
This loads variables and automatically launches PowerShell with them available.

Both scripts will:
- Read your `.env` file
- Parse KEY=VALUE pairs
- Set them as environment variables
- Display what was loaded

## Authenticate with Azure

Make sure you're logged in to Azure CLI:

```bash
az login
```

If you have multiple subscriptions, set the active subscription:

```bash
az account set --subscription "Your Subscription Name or ID"
```

## Run the Deployment Script

Navigate to the infrastructure directory and run the PowerShell deployment script. The script will automatically use environment variables if they've been loaded.

### Option 1: Load Environment Variables First (Recommended)

1. **Load environment variables:**
   ```bash
   cd infra
   pwsh ./load-env.ps1
   ```

2. **Run the deployment script:**
   ```powershell
   .\deploy.ps1
   ```

### Option 2: Use Bash Loader Script

```bash
cd infra
./load-env.sh
```

This will load the environment variables and automatically launch PowerShell where you can run:

```powershell
.\deploy.ps1
```

### Option 3: Run with Parameters

You can also run the script with command-line parameters instead of using environment variables:

```powershell
.\deploy.ps1 `
  -SubscriptionId "00000000-0000-0000-0000-000000000000" `
  -ResourceGroup "rg-fraud-insider" `
  -Location "eastus" `
  -Prefix "finrt"
```

## What the Script Does

The deployment script will:
- Set the Azure subscription context
- Create the resource group
- Deploy all infrastructure components using Bicep templates:
  - Azure Kubernetes Service (AKS)
  - Azure Container Registry (ACR)
  - Azure Data Lake Storage (ADLS)
  - Event Hubs
  - Databricks workspace
- Extract deployment outputs and save them to `.out.env`
- Configure kubectl to connect to the AKS cluster
- Install the Flink Kubernetes operator via Helm

## Deployment Outputs

After successful deployment, the script creates a `.out.env` file in the project root with all the connection details and resource names:

```bash
# Example output file contents
AKS_NAME=aks-finrt-20230902
ACR_NAME=acrfinrt20230902
ACR_LOGIN_SERVER=acrfinrt20230902.azurecr.io
DBX_NAME=dbx-finrt-20230902
SA_NAME=safinrt20230902
EH_BROKER=finrt-eh.servicebus.windows.net:9093
EH_NS=finrt-eh
EH_SEND='Endpoint=sb://finrt-eh.servicebus.windows.net/;...'
EH_LISTEN='Endpoint=sb://finrt-eh.servicebus.windows.net/;...'
RESOURCE_GROUP=rg-fraud-insider
LOCATION=eastus
PREFIX=finrt
```

## Alternative: Run with Parameters

You can also run the script with command-line parameters instead of using the `.env` file:

```powershell
.\deploy.ps1 `
  -SubscriptionId "00000000-0000-0000-0000-000000000000" `
  -ResourceGroup "rg-fraud-insider" `
  -Location "eastus" `
  -Prefix "finrt"
```

## Troubleshooting

### Common Issues

1. **Missing Azure CLI authentication:**
   ```bash
   az login
   ```

2. **PowerShell not found:**
   - Install PowerShell Core: `sudo apt-get install -y powershell` (Ubuntu/Debian)
   - Or use `pwsh` if already installed

3. **Permission errors:**
   - Ensure your Azure account has sufficient permissions to create resources
   - Check that the subscription is active and not disabled

4. **Resource name conflicts:**
   - Change the `PREFIX` value if resource names are already taken
   - Azure resource names must be globally unique for some services

### Cleanup

To remove all deployed resources:

```bash
az group delete --name "your-resource-group-name" --yes --no-wait
```

## Next Steps

After successful deployment:

1. **Build and deploy the Flink application:**
   ```bash
   cd flink
   ./build.sh
   ```

2. **Run the data producers:**
   ```bash
   cd producers
   ./run_producers.sh
   ```

3. **Access Databricks workspace:**
   - Use the `DBX_NAME` from `.out.env` to access your Databricks workspace
   - Upload and run the notebooks in the `databricks/` directory

## Support

For issues with the deployment:
- Check the Azure portal for resource deployment status
- Review the script output for error messages
- Ensure all prerequisites are properly installed and configured