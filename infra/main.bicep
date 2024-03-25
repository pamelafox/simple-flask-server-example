targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name which is used to generate a short unique hash for each resource')
param name string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Id of the user or app to assign application roles')
param principalId string = ''

@description('Flag to use free sku for App Service (limited availability)')
param useFreeSku bool = false

var resourceToken = toLower(uniqueString(subscription().id, name, location))
var tags = { 'azd-env-name': name }

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${name}-rg'
  location: location
  tags: tags
}

var prefix = '${name}-${resourceToken}'



module web 'core/host/appservice.bicep' = {
  name: 'appservice'
  scope: resourceGroup
  params: {
    name: '${prefix}-appservice'
    location: location
    tags: union(tags, { 'azd-service-name': 'web' })
    appServicePlanId: appServicePlan.outputs.id
    runtimeName: 'python'
    runtimeVersion: '3.10'
    scmDoBuildDuringDeployment: true
    ftpsState: 'Disabled'
    use32BitWorkerProcess: useFreeSku
    alwaysOn: !useFreeSku
  }
}

module appServicePlan 'core/host/appserviceplan.bicep' = {
  name: 'serviceplan'
  scope: resourceGroup
  params: {
    name: '${prefix}-serviceplan'
    location: location
    tags: tags
    sku: {
      name: useFreeSku ? 'F1' : 'B1'
    }
    reserved: true
  }
}

module registration 'appregistration.bicep' = {
  name: 'reg'
  scope: resourceGroup
  params: {
    keyVaultName: '${take(prefix, 21)}-kv'
    location: location
    tags: tags
    principalId: principalId
    appEndpoint: web.outputs.uri
  }
}
module appupdate 'appupdate.bicep' = {
  name: 'appupdate'
  scope: resourceGroup
  params: {
    appServiceName: web.outputs.name
    authClientId: registration.outputs.clientAppId
    authCertThumbprint: registration.outputs.certThumbprint
    authIssuerUri: '${environment().authentication.loginEndpoint}${tenant().tenantId}/v2.0'
  }
}


output WEB_URI string = web.outputs.uri
output AZURE_LOCATION string = location
