param apiManagementServiceName string = 'apiservicez7wp5i6mmw6nq'
param backendUris array

resource apiManagementService 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: apiManagementServiceName
}

// import openAI API...
resource azureOpenAIApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  parent: apiManagementService
  name: 'azure-openai-api'
  properties: {
    path: '/openai'
    displayName: 'AzureOpenAI'
    protocols: ['https']
    format: 'openapi+json'
  }
}

// Load the schema files.
var inputSchemaContent = loadTextContent('./gptinputSchema.json')
var outputSchemaContent = loadTextContent('./gptoutputSchema.json')

// Define the input and output schemas for openAI apis ...
resource inputSchema 'Microsoft.ApiManagement/service/apis/schemas@2023-05-01-preview' = {
  parent: azureOpenAIApi
  name: 'inputSchema'
  properties: {
    contentType: 'application/json'
    document: {
      value: inputSchemaContent
    }
  }
}

resource outputSchema 'Microsoft.ApiManagement/service/apis/schemas@2023-05-01-preview' = {
  parent: azureOpenAIApi
  name: 'outputSchema'
  properties: {
    contentType: 'application/json'
    document: {
      value: outputSchemaContent
    }
  }
}

// get endpoints array ...
var endpoints = loadJsonContent('./apimendpoints.json')
resource azureOpenAIApiOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = [
  for (endpoint, i) in endpoints: {
    parent: azureOpenAIApi
    name: endpoint.name
    properties: {
      displayName: endpoint.displayName
      method: endpoint.method
      urlTemplate: endpoint.urlTemplate
      request: {
        description: endpoint.description
        queryParameters: []
        headers: []
        representations: [
          {
            contentType: 'application/json'
            schemaId: 'inputSchema'
          }
        ]
      }
      responses: [
        {
          statusCode: 200
          description: 'Successful response'
          representations: [
            {
              contentType: 'application/json'
              schemaId: 'outputSchema'
            }
          ]
        }
      ]
    }
    dependsOn: [
      inputSchema
      outputSchema
    ]
  }
]

// add backend services ... 
resource backend 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = [
  for (backendUri, i) in backendUris: {
    parent: apiManagementService
    name: 'aoai-${i}'
    properties: {
      url: backendUri
      protocol: 'http'
      circuitBreaker: {
        rules: [
          {
            name: 'breakerRule'
            failureCondition: {
              count: 1
              interval: 'PT1M'
              statusCodeRanges: [
                {
                  min: 429
                  max: 429
                }
              ]
              errorReasons: ['timeout']
            }
            tripDuration: 'PT1M'
            acceptRetryAfter: true
          }
        ]
      }
    }
  }
]

var backendNames = [for i in range(0, length(backendUris)): backend[i].name]

// create backend pool for Load Balancing
resource backendpool 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = {
  parent: apiManagementService
  name: 'aoai-lb-pool'
  properties: {
    title: 'aoai-lb-pool'
    type: 'Pool'
    pool: {
      services: [
        for (backend, i) in backendNames: {
          id: '/backends/${backend}'
          priority: i % 2 == 0 ? 1 : 2
          weight: i + 1
        }
      ]
    }
  }
  dependsOn: [
    backend
  ]
}
