provider 'microsoftGraph@1.0.0'

@description('Specifies the name of the key vault.')
param keyVaultName string
param location string = resourceGroup().location
param tags object = {}

param principalId string

@description('Specifies the permissions to keys in the vault. Valid values are: all, encrypt, decrypt, wrapKey, unwrapKey, sign, verify, get, list, create, update, import, delete, backup, restore, recover, and purge.')
param keysPermissions array = [
  'list'
]

@description('Specifies the permissions to secrets in the vault. Valid values are: all, get, list, set, delete, backup, restore, recover, and purge.')
param secretsPermissions array = [
  'list'
  'get'
]

@description('Specifies the ID of the user-assigned managed identity.')
param identityName string = 'DeploymentScriptsIdentity2'

@description('Specifies the permissions to certificates in the vault. Valid values are: all, get, list, update, create, import, delete, recover, backup, restore, manage contacts, manage certificate authorities, get certificate authorities, list certificate authorities, set certificate authorities, delete certificate authorities.')
param certificatesPermissions array = [
  'get'
  'list'
  'update'
  'create'
]
param certificateName string = 'DeploymentScripts2019'
param subjectName string = 'CN=contoso.com'
param utcValue string = utcNow()
param appEndpoint string

resource webIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName // TODO: replace with a unique value
  location: location
}

resource keyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    //enabledForDeployment: enabledForDeployment
    //enabledForTemplateDeployment: enabledForTemplateDeployment
    tenantId: subscription().tenantId
    sku: {
      name: 'standard'
      family: 'A'
    }
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    accessPolicies: [
      {
        objectId: principalId
        tenantId: subscription().tenantId
        permissions: {
          keys: keysPermissions
          secrets: secretsPermissions
          certificates: certificatesPermissions
        }
      }
      {
        objectId: webIdentity.properties.principalId
        tenantId: subscription().tenantId
        permissions: {
          keys: keysPermissions
          secrets: secretsPermissions
          certificates: certificatesPermissions
        }
      }
    ]

  }
}


resource createAddCertificate 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'createAddCertificate2' // TODO: replace with a unique value
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${webIdentity.id}': {}
    }
  }
  kind: 'AzurePowerShell'
  properties: {
    forceUpdateTag: utcValue
    azPowerShellVersion: '8.3'
    timeout: 'PT30M'
    arguments: ' -vaultName ${keyVaultName} -certificateName ${certificateName} -subjectName ${subjectName}'
    scriptContent: '''
      param(
        [string] [Parameter(Mandatory=$true)] $vaultName,
        [string] [Parameter(Mandatory=$true)] $certificateName,
        [string] [Parameter(Mandatory=$true)] $subjectName
      )

      $ErrorActionPreference = 'Stop'
      $DeploymentScriptOutputs = @{}

      $existingCert = Get-AzKeyVaultCertificate -VaultName $vaultName -Name $certificateName

      if ($existingCert -and $existingCert.Certificate.Subject -eq $subjectName) {
        Write-Host 'Certificate $certificateName in vault $vaultName is already present.'

        $certValue = (Get-AzKeyVaultSecret -VaultName $vaultName -Name $certificateName).SecretValue | ConvertFrom-SecureString -AsPlainText
        $pfxCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList @([Convert]::FromBase64String($certValue),"",[System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
        $publicKey = [System.Convert]::ToBase64String($pfxCert.GetRawCertData())

        $DeploymentScriptOutputs['certStart'] = $existingCert.notBefore
        $DeploymentScriptOutputs['certEnd'] = $existingCert.expires
        $DeploymentScriptOutputs['certThumbprint'] = $existingCert.Thumbprint
        $DeploymentScriptOutputs['certKey'] = $publicKey
        $existingCert | Out-String
      } else {
        $policy = New-AzKeyVaultCertificatePolicy -SubjectName $subjectName -IssuerName Self -ValidityInMonths 12 -Verbose

        # private key is added as a secret that can be retrieved in the ARM template
        Add-AzKeyVaultCertificate -VaultName $vaultName -Name $certificateName -CertificatePolicy $policy -Verbose

        $newCert = Get-AzKeyVaultCertificate -VaultName $vaultName -Name $certificateName

        # it takes a few seconds for KeyVault to finish
        $tries = 0
        do {
          Write-Host 'Waiting for certificate creation completion...'
          Start-Sleep -Seconds 10
          $operation = Get-AzKeyVaultCertificateOperation -VaultName $vaultName -Name $certificateName
          $tries++

          if ($operation.Status -eq 'failed')
          {
            throw 'Creating certificate $certificateName in vault $vaultName failed with error $($operation.ErrorMessage)'
          }

          if ($tries -gt 120)
          {
            throw 'Timed out waiting for creation of certificate $certificateName in vault $vaultName'
          }
        } while ($operation.Status -ne 'completed')

        $Secret = Get-AzKeyVaultSecret -VaultName $vaultName -Name $certificateName

        $DeploymentScriptOutputs['certStart'] = $newCert.notBefore
        $DeploymentScriptOutputs['certEnd'] = $newCert.expires
        $DeploymentScriptOutputs['certThumbprint'] = $newCert.Thumbprint
        $DeploymentScriptOutputs['certKey'] = ConvertFrom-SecureString $Secret.SecretValue
        $newCert | Out-String
      }
    '''
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
  dependsOn: [
    keyVault
  ]
}

resource clientApp 'Microsoft.Graph/applications@beta' = {
  uniqueName: 'WebApp123456'
  displayName: 'ChatGPT Sample Client App TODO-1234456' // TODO: replace with a unique value
  signInAudience: 'AzureADMyOrg'
  web: {
      redirectUris: [
        'http://localhost:50505/.auth/login/aad/callback'
        '${appEndpoint}/.auth/login/aad/callback'
      ]
      implicitGrantSettings: {enableIdTokenIssuance: true}
  }
  spa: {
    redirectUris: [
      'http://localhost:50505/redirect'
      '${appEndpoint}/redirect'
    ]
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
  keyCredentials: [
    {
      displayName: 'Example Client App Key Credential'
      usage: 'Verify'
      type: 'AsymmetricX509Cert'
      key: createAddCertificate.properties.outputs.certKey
      startDateTime: createAddCertificate.properties.outputs.certStart
      endDateTime: createAddCertificate.properties.outputs.certEnd
    }
  ]
}

resource clientSp 'Microsoft.Graph/servicePrincipals@beta' = {
  appId: clientApp.appId
}

output clientAppId string = clientApp.appId
output clientSpId string = clientSp.id
output certThumbprint string = createAddCertificate.properties.outputs.certThumbprint
output keyVaultName string = keyVault.name