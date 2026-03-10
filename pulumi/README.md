# Pulumi Auth0 Infrastructure (.NET)

This Pulumi project manages Auth0 baseline resources for Polyphony using C#/.NET:

- Auth0 API resource server (`ResourceServer`)
- Auth0 App resource server (`ResourceServer`)
- Auth0 database connection (`Connection`, strategy `auth0`)
- Flutter Web Auth0 application (`Client`, SPA)
- Flutter Native Auth0 application (`Client`, Native)
- App machine-to-machine client (`Client`, Non-interactive)
- API machine-to-machine client (`Client`, Non-interactive)
- Client grants for app/api M2M clients to their corresponding resource servers (`ClientGrant`)
- Database connection to application-client mapping (`ConnectionClients`)
- GitHub Actions repository secrets for frontend release builds (`ActionsSecret`)

## Current Auth0 model

- Single tenant policy: use `dev-polyphony` tenant for all environments.
- API audience: `https://api.polyphony.com`.
- App origin identifier: `https://app.polyphony.com`.
- Organization support is intentionally out of scope.

## Managed resources (source of truth: `Program.cs`)

`pulumi/Program.cs` currently creates:

1. `ResourceServer` named `polyphony-api`
- Identifier: `https://api.polyphony.com`
- Signing algorithm: `RS256`
- Token lifetime: `3600` seconds

2. `ResourceServer` named `polyphony-app`
- Identifier: `https://app.polyphony.com`
- Signing algorithm: `RS256`
- Token lifetime: `3600` seconds

3. `Connection` named `polyphony-database`
- Connection strategy: `auth0`
- Connection name: `polyphony-users`

4. `Client` named `polyphony-web`
- App type: `spa`
- OIDC conformant: true
- Grant types: `authorization_code`, `refresh_token`
- Callback/logout/origin values come from Pulumi config list keys:
	- `flutterWebCallbackUrls`
	- `flutterWebLogoutUrls`
	- `flutterWebOrigins`

5. `Client` named `polyphony-native`
- App type: `native`
- OIDC conformant: true
- Grant types: `authorization_code`, `refresh_token`
- Callback and logout URIs are provided by Pulumi config list key `flutterNativeRedirectUris`

6. `Client` named `polyphony-app-service`
- App type: `non_interactive`
- OIDC conformant: true
- Grant type: `client_credentials`

7. `Client` named `polyphony-api-service`
- App type: `non_interactive`
- OIDC conformant: true
- Grant type: `client_credentials`
- Allowed origins use Pulumi config list key `backendApiBaseUrls`

8. `ConnectionClients` mapping
- Enables the database connection for:
	- `polyphony-web`
	- `polyphony-native`

9. `ClientGrant` named `polyphony-app-client-grant`
- Client: `polyphony-app-service`
- Audience: `https://app.polyphony.com`

10. `ClientGrant` named `polyphony-api-client-grant`
- Client: `polyphony-api-service`
- Audience: `https://api.polyphony.com`

## Prerequisites

- Pulumi CLI
- .NET SDK 8+
- Access to Auth0 tenant with M2M credentials for management API

## 1) Login to Pulumi

```powershell
pulumi login
```

## 2) Configure Auth0 provider credentials

Use Pulumi ESC to host provider credentials and project variables.

Create an ESC environment (for example `polyphony/polyphony-infrastructure/dev`) and
populate the `pulumiConfig` keys shown in `esc-auth0-dev.example.yaml`.

Important:
- Keep `auth0:clientSecret` as a secret in ESC.
- Do not commit real secrets to git.

Required Pulumi config values for this project:
- `flutterNativeRedirectUris`
- `flutterWebCallbackUrls`
- `flutterWebLogoutUrls`
- `flutterWebOrigins`
- `backendApiBaseUrls`
- `frontendBackendBaseUrl`

Required Pulumi provider config values for Sentry (in ESC/stack config):
- `sentry:token` (secret)

Required Pulumi project config values for Sentry:
- `sentryOrganization`
- `sentryUploadAuthToken` (secret used only for GitHub Actions uploads)

Optional Pulumi config values for importing existing Sentry keys:
- `sentry:backendKeyId` (used for `backend` project key import id)
- `sentry:frontendKeyId` (used for `frontend` project key import id)

Optional Pulumi config values:
- `githubOwner` (defaults to `polyphony-org`)
- `githubRepository` (defaults to `polyphony`)
- `frontendSentryTracesSampleRate` (defaults to `1.0`)

Pulumi uses the GitHub provider to create these repository Actions variables for frontend release builds:
- `POLYPHONY_BACKEND_BASE_URL`
- `AUTH0_DOMAIN`

Pulumi also manages these Sentry GitHub Actions settings:
- Secrets:
	- `SENTRY_AUTH_TOKEN`
	- `SENTRY_ORG`
- Variables:
	- `SENTRY_BACKEND_PROJECT`
	- `SENTRY_FRONTEND_PROJECT`
	- `SENTRY_BACKEND_DSN`
	- `SENTRY_FRONTEND_DSN`
	- `SENTRY_TRACES_SAMPLE_RATE`

Import IDs used by Pulumi resources in this project:
- `github:index/actionsSecret:ActionsSecret`: `repository:secret_name` (for example `polyphony:SENTRY_ORG`)
- `github:index/actionsVariable:ActionsVariable`: `repository:variable_name` (for example `polyphony:SENTRY_BACKEND_DSN`)
- `sentry:index/sentryProject:SentryProject`: `organization/project_slug` (for example `my-org/backend`)
- `sentry:index/sentryKey:SentryKey`: `organization/project_slug/key_id` (for example `my-org/backend/abc123def456`)

Use the pulumi 

```powershell
gh auth login
```

## 3) Create stack and attach ESC environment

```powershell
pulumi stack init dev
```

Then create your stack file from the example and set the ESC environment reference:

```powershell
Copy-Item Pulumi.dev.example.yaml Pulumi.dev.yaml
```

`Pulumi.dev.yaml`:

```yaml
environments:
	- polyphony/polyphony-infrastructure/dev
```

If Pulumi warns that the environment has no effect, your ESC environment is missing
`values.pulumiConfig` (or `environmentVariables`/`files`).

## 4) Preview and deploy

```powershell
pulumi preview
pulumi up
```

## 5) Read outputs

```powershell
pulumi stack output
```

Outputs include Auth0 app client IDs and API identifier for wiring backend and Flutter config.

Current outputs:
- `auth0ApiIdentifier`
- `auth0ApiId`
- `auth0AppIdentifier`
- `auth0AppId`
- `auth0DatabaseConnectionName`
- `auth0DatabaseConnectionId`
- `flutterWebClientId`
- `flutterNativeClientId`
- `appM2mClientId`
- `backendM2mClientId`
- `appClientGrantId`
- `apiClientGrantId`
- `databaseConnectionClientsId`
- `frontendBackendBaseUrlVariableName`
- `frontendAuth0DomainVariableName`
- `sentryOrganizationSecretName`
- `sentryAuthTokenSecretName`
- `sentryBackendProjectVariableName`
- `sentryFrontendProjectVariableName`
- `sentryBackendDsnVariableName`
- `sentryFrontendDsnVariableName`
- `sentryFrontendTracesSampleRateVariableName`
