// param tags object
param suffix string
param apimIdentityName string

// loop insdie main.json and retrun all instance 

// load json file ...
var content = loadJsonContent('./model.json')

// resource modelInstances 'Microsoft.Resources/deployments@2021-04-01' = [for model in content: {
module modelInstances './model.bicep' = [
  for model in content: {
    name: '${model.name}${suffix}'
    params: {
      // tags: tags
      // workspaceId: workspaceId
      location: model.location
      name: '${model.name}${suffix}'
      openAIModels: model.models
      apimIdentityName: apimIdentityName
    }
  }
]

// output an array of the model name and Id 
var arrayOutput = [
  for model in content: {
    name: model.name
    id: resourceId('Microsoft.Resources/deployments', '${model.name}${suffix}')
  }
]

output OpenAiInstances array = arrayOutput
output openAIurls array = [for i in range(0, length(content)): modelInstances[i].outputs.url]
