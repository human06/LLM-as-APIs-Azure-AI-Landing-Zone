targetScope = 'subscription'
param resourceGroupName string
param suffix string
param location string = deployment().location

// resources ...

// RG
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

// appinsights
module appInsights './appinsights/model.bicep' = {
  name: 'appInsights'
  scope: resourceGroup
  params: {
    location: location
    suffix: suffix
  }
}

// apim ...
module apiManagement './apim/model.bicep' = {
  name: 'apiManagement'
  scope: resourceGroup
  params: {
    location: location
    suffix: suffix
    appInsightsName: appInsights.outputs.appInsightsName
  }
}

// openAI 
module openAI './openai/main.bicep' = {
  name: 'openAI'
  scope: resourceGroup
  params: {
    apimIdentityName: apiManagement.outputs.apimIdentityName
    suffix: suffix
  }
}


// apim backend 
module apimBackend './apim/apimbackend.bicep' = {
  name: 'apimBackend'
  scope: resourceGroup
  params: {
     apiManagementServiceName: apiManagement.outputs.apimName
     backendUris: openAI.outputs.openAIurls
  }
}

// apim policy 
module apiPolicy './apim/apimpolicy.bicep' = {
  name: 'apiPolicy'
  scope: resourceGroup
  params: {
    apiManagementServiceName: apiManagement.outputs.apimName
  }
  dependsOn: [
    apimBackend
  ]
}

// log ...
module apiLogger './apim/apimlogger.bicep' = {
  name: 'apiLogger'
  scope: resourceGroup
  params: {
    apiManagementServiceName: apiManagement.outputs.apimName
    appInsightsLoggerId: apiManagement.outputs.appInsightsLoggerId
  }
  dependsOn: [
    apiPolicy
  ]
}
