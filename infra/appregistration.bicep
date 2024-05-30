provider microsoftGraph

@description('Specifies the ID of the user-assigned managed identity.')
param webAppIdentityId string

@description('Specifies the unique name for the client application.')
param clientAppName string

@description('Specifies the display name for the client application')
param clientAppDisplayName string

param serviceManagementReference string = ''

param issuer string

param webAppEndpoint string


resource clientApp 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: clientAppName
  displayName: clientAppDisplayName
  signInAudience: 'AzureADMyOrg'
  serviceManagementReference: empty(serviceManagementReference) ? null : serviceManagementReference
  web: {
      redirectUris: [
        'http://localhost:50505/.auth/login/aad/callback'
        '${webAppEndpoint}/.auth/login/aad/callback'
      ]
      implicitGrantSettings: {enableIdTokenIssuance: true}
  }
  requiredResourceAccess: [
    {
      resourceAppId: '00000003-0000-0000-c000-000000000000'
      resourceAccess: [
        // Graph User.Read
        {id: 'e1fe6dd8-ba31-4d61-89e7-88639da4683d', type: 'Scope'}
        // offline_access
        {id: '7427e0e9-2fba-42fe-b0c0-848c9e6a8182', type: 'Scope'}
        // openid
        {id: '37f7f235-527c-4136-accd-4a02d197296e', type: 'Scope'}
        // profile
        {id: '14dad69e-099b-42c9-810b-d002981feec1', type: 'Scope'}
      ]
    }
  ]

  resource clientAppFic 'federatedIdentityCredentials@v1.0' = {
    name: '${clientApp.uniqueName}/miAsFic'
    audiences: ['api://AzureADTokenExchange']
    issuer: issuer
    subject: webAppIdentityId
  }
}



resource clientSp 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: clientApp.appId
}

output clientAppId string = clientApp.appId
output clientSpId string = clientSp.id
