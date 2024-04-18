param name string
param location string = resourceGroup().location
param tags object = {}

param serviceName string = 'web'
param appServicePlanId string
param useFreeSku bool = false

resource webIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${name}-id'
  location: location
}


module web 'core/host/appservice.bicep' = {
  name: 'appservice'
  params: {
    name: name
    location: location
    tags: union(tags, { 'azd-service-name': serviceName })
    appServicePlanId: appServicePlanId
    runtimeName: 'python'
    runtimeVersion: '3.10'
    scmDoBuildDuringDeployment: true
    ftpsState: 'Disabled'
    use32BitWorkerProcess: useFreeSku
    alwaysOn: !useFreeSku
    userManagedIdentityId: webIdentity.id
    appSettings: {
      OVERRIDE_USE_MI_FIC_ASSERTION_CLIENTID: webIdentity.properties.clientId
      WEBSITE_LWAS_FALLBACK: 'true'
    }
  }
}


output identityPrincipalId string = webIdentity.properties.principalId
output uri string = web.outputs.uri
output name string = web.outputs.name
