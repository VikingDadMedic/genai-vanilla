// GenAI Stack - Azure Deployment with Bicep
// Azure-native Infrastructure as Code

targetScope = 'subscription'

// Parameters
@description('Environment name')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'prod'

@description('Azure region for resources')
param location string = 'eastus'

@description('Project name')
param projectName string = 'genai'

@description('Deployment type')
@allowed(['aca', 'vm'])
param deploymentType string = 'aca'

@description('Enable GPU for AI workloads')
param enableGpu bool = false

@description('Use Azure OpenAI instead of self-hosted')
param useAzureOpenAI bool = true

@description('Administrator username')
@secure()
param adminUsername string = 'genaiuser'

@description('SSH public key for VM access')
@secure()
param sshPublicKey string

// Variables
var resourcePrefix = '${projectName}-${environment}'
var uniqueSuffix = uniqueString(subscription().subscriptionId, resourcePrefix)
var tags = {
  Project: projectName
  Environment: environment
  ManagedBy: 'Bicep'
  CreatedAt: utcNow()
}

// Resource Group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${resourcePrefix}-rg'
  location: location
  tags: tags
}

// Modules
module networking 'modules/networking.bicep' = {
  scope: resourceGroup
  name: 'networking'
  params: {
    prefix: resourcePrefix
    location: location
    tags: tags
  }
}

module containerRegistry 'modules/container-registry.bicep' = {
  scope: resourceGroup
  name: 'container-registry'
  params: {
    name: '${replace(resourcePrefix, '-', '')}acr'
    location: location
    tags: tags
  }
}

module monitoring 'modules/monitoring.bicep' = {
  scope: resourceGroup
  name: 'monitoring'
  params: {
    name: '${resourcePrefix}-logs'
    location: location
    tags: tags
  }
}

module postgresql 'modules/postgresql.bicep' = {
  scope: resourceGroup
  name: 'postgresql'
  params: {
    name: '${resourcePrefix}-postgres'
    location: location
    administratorLogin: 'genaidbadmin'
    delegatedSubnetId: networking.outputs.postgresSubnetId
    privateDnsZoneId: networking.outputs.postgresDnsZoneId
    tags: tags
  }
}

module redis 'modules/redis.bicep' = {
  scope: resourceGroup
  name: 'redis'
  params: {
    name: '${resourcePrefix}-redis'
    location: location
    tags: tags
  }
}

module storage 'modules/storage.bicep' = {
  scope: resourceGroup
  name: 'storage'
  params: {
    name: '${replace(resourcePrefix, '-', '')}sto${uniqueSuffix}'
    location: location
    tags: tags
  }
}

// Container Apps Environment (if using ACA)
module containerAppsEnvironment 'modules/container-apps-env.bicep' = if (deploymentType == 'aca') {
  scope: resourceGroup
  name: 'container-apps-environment'
  params: {
    name: '${resourcePrefix}-env'
    location: location
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
    subnetId: networking.outputs.containerAppsSubnetId
    tags: tags
  }
}

// Container Apps
module containerApps 'modules/container-apps.bicep' = if (deploymentType == 'aca') {
  scope: resourceGroup
  name: 'container-apps'
  params: {
    environmentId: containerAppsEnvironment.outputs.environmentId
    containerRegistryUrl: containerRegistry.outputs.loginServer
    containerRegistryUsername: containerRegistry.outputs.adminUsername
    containerRegistryPassword: containerRegistry.outputs.adminPassword
    
    postgresHost: postgresql.outputs.fqdn
    postgresUser: postgresql.outputs.administratorLogin
    postgresPassword: postgresql.outputs.administratorPassword
    
    redisHost: redis.outputs.hostname
    redisKey: redis.outputs.primaryKey
    
    storageAccountName: storage.outputs.accountName
    storageAccountKey: storage.outputs.primaryKey
    
    location: location
    tags: tags
  }
}

// Azure OpenAI (if enabled)
module azureOpenAI 'modules/azure-openai.bicep' = if (useAzureOpenAI) {
  scope: resourceGroup
  name: 'azure-openai'
  params: {
    name: '${resourcePrefix}-openai'
    location: location
    tags: tags
  }
}

// GPU VM (if enabled)
module gpuVm 'modules/gpu-vm.bicep' = if (enableGpu) {
  scope: resourceGroup
  name: 'gpu-vm'
  params: {
    name: '${resourcePrefix}-gpu'
    location: location
    vmSize: 'Standard_NC8as_T4_v3'
    useSpot: true
    maxBidPrice: '0.20'
    subnetId: networking.outputs.gpuSubnetId
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    tags: tags
  }
}

// Key Vault for secrets
module keyVault 'modules/keyvault.bicep' = {
  scope: resourceGroup
  name: 'keyvault'
  params: {
    name: '${resourcePrefix}-kv-${uniqueSuffix}'
    location: location
    tags: tags
  }
}

// Outputs
output resourceGroupName string = resourceGroup.name
output containerAppsUrls object = deploymentType == 'aca' ? containerApps.outputs.appUrls : {}
output postgresFqdn string = postgresql.outputs.fqdn
output redisHostname string = redis.outputs.hostname
output storageAccountName string = storage.outputs.accountName
output azureOpenAIEndpoint string = useAzureOpenAI ? azureOpenAI.outputs.endpoint : ''
output gpuVmPublicIp string = enableGpu ? gpuVm.outputs.publicIp : ''

output deploymentInfo object = {
  environment: environment
  deploymentType: deploymentType
  location: location
  gpuEnabled: enableGpu
  azureOpenAI: useAzureOpenAI
  resourceGroup: resourceGroup.name
}

// Deployment script to output configuration
resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  scope: resourceGroup
  name: 'output-config'
  location: location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '7.0'
    retentionInterval: 'P1D'
    scriptContent: '''
      $config = @"
# ============================================
# GENAI STACK AZURE CONFIGURATION
# Generated by Bicep deployment
# ============================================

RESOURCE_GROUP=${env:RESOURCE_GROUP}
ENVIRONMENT=${env:ENVIRONMENT}
DEPLOYMENT_TYPE=${env:DEPLOYMENT_TYPE}

# Container Apps URLs
${env:CONTAINER_APPS_URLS}

# Database
POSTGRES_HOST=${env:POSTGRES_HOST}
POSTGRES_USER=genaidbadmin

# Redis
REDIS_HOST=${env:REDIS_HOST}

# Storage
STORAGE_ACCOUNT=${env:STORAGE_ACCOUNT}

# Azure OpenAI
AZURE_OPENAI_ENDPOINT=${env:OPENAI_ENDPOINT}

# GPU VM (if enabled)
GPU_VM_IP=${env:GPU_VM_IP}
"@
      
      $DeploymentScriptOutputs = @{
        config = $config
      }
    '''
    environmentVariables: [
      {
        name: 'RESOURCE_GROUP'
        value: resourceGroup.name
      }
      {
        name: 'ENVIRONMENT'
        value: environment
      }
      {
        name: 'DEPLOYMENT_TYPE'
        value: deploymentType
      }
      {
        name: 'CONTAINER_APPS_URLS'
        value: string(containerAppsUrls)
      }
      {
        name: 'POSTGRES_HOST'
        value: postgresFqdn
      }
      {
        name: 'REDIS_HOST'
        value: redisHostname
      }
      {
        name: 'STORAGE_ACCOUNT'
        value: storageAccountName
      }
      {
        name: 'OPENAI_ENDPOINT'
        value: azureOpenAIEndpoint
      }
      {
        name: 'GPU_VM_IP'
        value: gpuVmPublicIp
      }
    ]
  }
}
