// create APIM 
param apiManagementServiceName string = 'apiservice${uniqueString(resourceGroup().id)}'
param location string = resourceGroup().location
param skuCount int = 1
param appInsightsName string
param suffix string


// variables
var apimIdentityName = 'identity-${suffix}'
var apimIdentityNameValue = 'apim-identity'

// load dynamic APIM settings 
var content = loadJsonContent('model.json')



// create APIM user assigned identity
resource apimIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: apimIdentityName
  location: location
}

// create APIM service ...
resource apiManagementService 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: apiManagementServiceName
  location: location
  sku: {
    name: 'Developer'
    capacity: skuCount
  }
  identity: {
    type:'UserAssigned'
    userAssignedIdentities: {
      '${apimIdentity.id}': {}
    }
  }
  properties: {
    publisherEmail: content.publisherEmail
    publisherName: content.publisherName
  }
}


// application insights for logs ... 
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}


resource apim_appInsightsLogger_resource 'Microsoft.ApiManagement/service/loggers@2019-01-01' = {
  parent: apiManagementService
  name: appInsightsName
  properties: {
    loggerType: 'applicationInsights'
    resourceId: applicationInsights.id
    credentials: {
      instrumentationKey: applicationInsights.properties.InstrumentationKey
    }
  }
}


resource apimOpenaiApiUamiNamedValue 'Microsoft.ApiManagement/service/namedValues@2022-08-01' = {
  name: apimIdentityNameValue
  parent: apiManagementService
  properties: {
    displayName: apimIdentityNameValue
    secret: true
    value: apimIdentity.properties.clientId
  }
}


output apimIdentityName string = apimIdentity.name
output apimName string = apiManagementService.name
output appInsightsLoggerId string = apim_appInsightsLogger_resource.id
