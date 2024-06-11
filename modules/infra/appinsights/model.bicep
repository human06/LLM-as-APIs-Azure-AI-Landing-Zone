// appinsights ...
param location string = resourceGroup().location
param suffix string

var appInsightsName = 'appi-${suffix}'
var logAnalyticsWorkspaceName = 'log-${suffix}'


// resources ..

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  })
}


resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}


output appInsightsName string = appInsights.name
output appInsightsId string = appInsights.id
