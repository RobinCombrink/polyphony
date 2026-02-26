# Pulumi Auth0 Infrastructure (.NET)

This Pulumi project manages Auth0 baseline resources for Polyphony using C#/.NET:

- Auth0 API (`ResourceServer`) for backend audience
- Flutter Web Auth0 application (`Client`, SPA)
- Flutter Native Auth0 application (`Client`, Native)
- Backend machine-to-machine application (`Client`, Non-interactive)

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
