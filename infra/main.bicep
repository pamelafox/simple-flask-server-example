targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name which is used to generate a short unique hash for each resource')
param name string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Flag to use free sku for App Service (limited availability)')
param useFreeSku bool = false

@description('Service Management Reference for the app registration')
param serviceManagementReference string = ''

var resourceToken = toLower(uniqueString(subscription().id, name, location))
var tags = { 'azd-env-name': name }

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${name}-rg'
  location: location
  tags: tags
}

var prefix = '${name}-${resourceToken}'

module web 'web.bicep' = {
  name: 'web'
  scope: resourceGroup
  params: {
    name: replace('${take(prefix,19)}-web', '--', '-')
    location: location
    tags: tags
    appServicePlanId: appServicePlan.outputs.id
    useFreeSku: useFreeSku
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


var issuer = '${environment().authentication.loginEndpoint}${tenant().tenantId}/v2.0'
module registration 'appregistration.bicep' = {
  name: 'reg'
  scope: resourceGroup
  params: {
    clientAppName: '${prefix}-entra-client-app'
    clientAppDisplayName: 'Simple Flask Server Client App'
    webAppEndpoint: web.outputs.uri
    webAppIdentityId: web.outputs.identityPrincipalId
    issuer: issuer
    serviceManagementReference: serviceManagementReference
  }
}

module appupdate 'appupdate.bicep' = {
  name: 'appupdate'
  scope: resourceGroup
  params: {
    appServiceName: web.outputs.name
    clientId: registration.outputs.clientAppId
    openIdIssuer: issuer
  }
}

output WEB_URI string = web.outputs.uri
output AZURE_LOCATION string = location
