param appServiceName string

param authClientId string = ''
@secure()
param authCertThumbprint string = ''
param authIssuerUri string = ''

resource appService 'Microsoft.Web/sites@2022-03-01' existing = {
  name: appServiceName
}

resource configAuth 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: appService
  name: 'authsettingsV2'
  properties: {
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: 'RedirectToLoginPage'
      redirectToProvider: 'azureactivedirectory'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          clientId: authClientId
          clientSecretCertificateThumbprint: authCertThumbprint
          openIdIssuer: authIssuerUri
        }
        validation: {
          defaultAuthorizationPolicy: {
            allowedApplications: []
          }
        }
      }
    }
    login: {
      tokenStore: {
        enabled: true
      }
    }
  }
}
