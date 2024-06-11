// param tags object
param publicNetworkAccess string = 'Enabled'
param sku string = 'S0'
param location string
param name string
param openAIModels array
param apimIdentityName string


@description('the identity of the OpenAI resource.')
param identity object = {
  type: 'SystemAssigned'
}



// Variables
var diagnosticSettingsName = 'diagnosticSettings'
var openAiLogCategories = [
  'Audit'
  'RequestResponse'
  'Trace'
]
var openAiMetricCategories = [
  'AllMetrics'
]
var openAiLogs = [
  for category in openAiLogCategories: {
    category: category
    enabled: true
  }
]
var openAiMetrics = [
  for category in openAiMetricCategories: {
    category: category
    enabled: true
  }
]

// Resources

// create openAi resource
resource openAi 'Microsoft.CognitiveServices/accounts@2022-12-01' = {
  name: name
  location: location
  sku: {
    name: sku
  }
  kind: 'OpenAI'
  identity: identity
  // tags: tags
  properties: {
    publicNetworkAccess: publicNetworkAccess
    customSubDomainName: toLower(name)
  }
}

// modles for the OpenAI resource
resource model 'Microsoft.CognitiveServices/accounts/deployments@2022-12-01' = [
  for deployment in openAIModels: {
    name: deployment.name
    parent: openAi
    properties: {
      model: {
        format: 'OpenAI'
        name: deployment.name
        version: deployment.version
      }
      raiPolicyName: deployment.raiPolicyName
      scaleSettings: {
        capacity: deployment.capacity
        scaleType: deployment.scaleType
      }
    }
  }
]




// autherize apim to use the OpenAI resource
resource cognitiveServicesOpenAIUser 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd' // Cognitive Services OpenAI User
  scope: tenant()
}


resource apimIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: apimIdentityName
}


resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(openAi.id, apimIdentity.id, cognitiveServicesOpenAIUser.id)
  scope: openAi
  properties: {
    principalId: apimIdentity.properties.principalId
    roleDefinitionId: cognitiveServicesOpenAIUser.id
    principalType: 'ServicePrincipal'
  }
}

// Outputs
output id string = openAi.id
output name string = openAi.name
output url string = '${openAi.properties.endpoint}openai/'
