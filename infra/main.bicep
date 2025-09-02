param namePrefix string
param location string = resourceGroup().location

// Sizing
param aksNodeCount int = 2
param aksNodeSize string = 'Standard_D4s_v5'
param acrSku string = 'Standard'
param dbxSku string = 'premium'
param ehCapacity int = 2
param ehPartitions int = 12

// Names
var aksName = '${namePrefix}-aks'
var acrName = toLower(replace('${namePrefix}acr${uniqueString(resourceGroup().id)}','-',''))
var dbxName = '${namePrefix}-dbx'
var saName = toLower('${namePrefix}dls${uniqueString(resourceGroup().id)}')
var nsName = toLower('${namePrefix}-ehns')
var ehFraud = 'auth_txn'
var ehInsider = 'insider_events'

// ACR
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: { name: acrSku }
  properties: {
    adminUserEnabled: false
    policies: { quarantinePolicy: { status: 'disabled' } }
  }
}

// AKS (system-assigned identity)
resource aks 'Microsoft.ContainerService/managedClusters@2024-03-02-preview' = {
  name: aksName
  location: location
  identity: { type: 'SystemAssigned' }
  properties: {
    dnsPrefix: '${namePrefix}-aks'
    agentPoolProfiles: [
      {
        name: 'nodepool1'
        count: aksNodeCount
        vmSize: aksNodeSize
        osType: 'Linux'
        mode: 'System'
      }
    ]
    networkProfile: { networkPlugin: 'azure' }
  }
}

// Give AKS kubelet AcrPull on ACR
resource acrAksPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: acr
  name: guid(acr.id, 'AcrPull', aks.id)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions','7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: aks.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [ acr, aks ]
}

// ADLS Gen2
resource stg 'Microsoft.Storage/storageAccounts@2023-04-01' = {
  name: saName
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    isHnsEnabled: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${stg.name}/default/datalake'
}

// Event Hubs (for sample data; use Confluent Cloud if preferred)
resource ehns 'Microsoft.EventHub/namespaces@2024-01-01' = {
  name: nsName
  location: location
  sku: { name: 'Standard', tier: 'Standard', capacity: ehCapacity }
  properties: {
    zoneRedundant: false
    isAutoInflateEnabled: true
    maximumThroughputUnits: 20
  }
}

resource authHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' = {
  name: '${ehns.name}/${ehFraud}'
  properties: { partitionCount: ehPartitions, messageRetentionInDays: 1 }
}

resource insiderHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' = {
  name: '${ehns.name}/${ehInsider}'
  properties: { partitionCount: ehPartitions, messageRetentionInDays: 1 }
}

// SAS policies
resource sendRule 'Microsoft.EventHub/namespaces/authorizationRules@2024-01-01' = {
  name: '${ehns.name}/send'
  properties: { rights: [ 'Send' ] }
}

resource listenRule 'Microsoft.EventHub/namespaces/authorizationRules@2024-01-01' = {
  name: '${ehns.name}/listen'
  properties: { rights: [ 'Listen' ] }
}

// Databricks workspace
resource dbx 'Microsoft.Databricks/workspaces@2023-02-01' = {
  name: dbxName
  location: location
  sku: { name: dbxSku }
  properties: { parameters: { prepareEncryption: { value: 'false' } } }
}

// Outputs
var ehFqdn = '${ehns.name}.servicebus.windows.net:9093'

output aksNameOut string = aks.name
output acrNameOut string = acr.name
output acrLoginServer string = acr.properties.loginServer
output databricksWorkspace string = dbx.name
output saNameOut string = stg.name
output eventHubsKafkaBroker string = ehFqdn
output eventHubsNamespace string = ehns.name
output eventHubAuth string = authHub.name
output eventHubInsider string = insiderHub.name
output sendConn string = listKeys(resourceId('Microsoft.EventHub/namespaces/authorizationRules', ehns.name, sendRule.name), '2024-01-01').primaryConnectionString
output listenConn string = listKeys(resourceId('Microsoft.EventHub/namespaces/authorizationRules', ehns.name, listenRule.name), '2024-01-01').primaryConnectionString
