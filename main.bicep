param tenantId string = subscription().tenantId
param environmentName string

@description('Select the location for all resources')
@allowed(
  [
    'eastus2'
    'francecentral'
  ]
)
param location string


// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01'  = {
  name: 'stg${uniqueString(resourceGroup().id)}${environmentName}'
  kind: 'StorageV2'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  tags: {
    environment: environmentName
  }
}

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview'  =  {
  name: 'kv-ai-${uniqueString(resourceGroup().id)}-${environmentName}'
  location: location
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: []
  }
  tags: {
    environment: environmentName
  }
}

// app insight log workspace
resource appInsightsLogWorkspace 'Microsoft.OperationalInsights/workspaces@2020-08-01' = {
  name: 'appinsights-workspace-ai-${uniqueString(resourceGroup().id)}-${environmentName}'
  location: location
  tags: {
    environment: environmentName
  }
}

// Application Insights
resource applicationInsights 'Microsoft.Insights/components@2020-02-02'  = {
  name: 'appinsightsai${uniqueString(resourceGroup().id)}${environmentName}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: appInsightsLogWorkspace.id
  }
  tags: {
    environment: environmentName
  }
}

// azure AI service
resource azureAIService 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: 'ai-services-${uniqueString(resourceGroup().id)}-${environmentName}'
  location: location
  kind: 'AIServices'
  sku: {
    name: 'S0'
       }
  tags: {
    environment: environmentName
  }
}


// azure OpenAI endpoint
resource azureOpenAI 'Microsoft.CognitiveServices/accounts@2023-10-01-preview'  = {
  name: 'azopenai-${uniqueString(resourceGroup().id)}-${environmentName}'
  location: location
  sku: {
    name: 'S0'
  }
  kind: 'OpenAI'
  properties: {
    customSubDomainName: 'azopenai-${uniqueString(resourceGroup().id)}-${environmentName}'
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }
    publicNetworkAccess: 'Enabled'
  }
  tags: {
    environment: environmentName
  }
}


// Container Registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2022-02-01-preview'  = {
  name: 'acr${uniqueString(resourceGroup().id)}${environmentName}'
  location: location
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: false
    
  }
  tags: {
    environment: environmentName
  }
}

// AI Search
resource aiSearch 'Microsoft.Search/searchServices@2020-08-01'  = {
  name: 'aisearch-${uniqueString(resourceGroup().id)}-${environmentName}'
  location: location
  sku: {
    name: 'standard'
  }
  properties: {
   hostingMode: 'default'
    publicNetworkAccess: 'enabled'
  }
  tags: {
    environment: environmentName
  }
}

// Azure AI Resource - Hub
resource azureaiHubResource 'Microsoft.MachineLearningServices/workspaces@2023-02-01-preview'  = {
  name: 'ai-hub-${uniqueString(resourceGroup().id)}-${environmentName}'
  location: location
  kind: 'Hub'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: 'ai-hub-${uniqueString(resourceGroup().id)}-${environmentName}'
    storageAccount: storageAccount.id
    keyVault: keyVault.id 
    applicationInsights: applicationInsights.id
    containerRegistry: containerRegistry.id
    publicNetworkAccess: 'Enabled' 
     managedNetwork: {
      isolationMode: 'Disabled'
    }
     
    workspaceHubConfig: {
      defaultWorkspaceResourceGroup: resourceGroup().id
    }
  }
   sku: {
    name: 'Standard'
     }
  tags: {
    environment: environmentName
  } 
}

// Azure AI Resource - Project
resource azureaiProjectResource 'Microsoft.MachineLearningServices/workspaces@2023-10-01'  = {
  name: 'ai-project-${uniqueString(resourceGroup().id)}-${environmentName}'
  location: location
  kind: 'Project'
  dependsOn: [
    azureAIService
    azureOpenAI
  ]
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: 'ai-project-${uniqueString(resourceGroup().id)}-${environmentName}'
    publicNetworkAccess: 'Enabled'
   
   hbiWorkspace: false
   hubResourceId: azureaiHubResource.id    
  }
   sku: {
    name: 'Standard'
     }
  tags: {
    environment: environmentName
  }  
}




// Marketplace Subscription to Mistral Large
resource marketplace 'Microsoft.MachineLearningServices/workspaces/marketplaceSubscriptions@2024-01-01-preview' = {
  name: 'marketplace-sub-${uniqueString(resourceGroup().id)}-${environmentName}'
  parent: azureaiProjectResource
   properties:{
    modelId: 'azureml://registries/azureml-mistral/models/Mistral-large'
    marketplacePublisherId: '000-000'
    marketplaceOfferId: 'mistral-ai-large-offer'
    marketplacePlanId: 'mistral-large-2402-plan'
   }
}

// mistral large serverless endpoint
resource MistralserverlessEndpoint 'Microsoft.MachineLearningServices/workspaces/serverlessEndpoints@2024-01-01-preview' = {
  name: 'mistrallarge${environmentName}'
  kind: 'Mistral'
  location: location
  parent: azureaiProjectResource
  sku: {
    name: 'Consumption'
     }
 properties:{
   authMode: 'Key'
  
   modelSettings:{
     modelId: 'azureml://registries/azureml-mistral/models/Mistral-large'
      }
   offer: null
       }
  }

  az vm image terms accept --urn Mistral:mistral-ai-large-offer:mistral-large-2402-plan:latest
