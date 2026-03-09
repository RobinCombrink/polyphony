using Pulumi;
using Pulumi.Auth0;
using Pulumi.Auth0.Inputs;

return await Deployment.RunAsync(() =>
{
    var config = new Pulumi.Config();
    var auth0Config = new Pulumi.Config("auth0");

    const string auth0DatabaseConnectionName = "polyphony-users";

    List<string> RequireStringList(string key)
    {
        var values = config.RequireObject<List<string>>(key);

        var normalized = values
            .Where(value => !string.IsNullOrWhiteSpace(value))
            .Select(value => value.Trim())
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

        if (normalized.Count == 0)
        {
            throw new RunException($"Missing required Pulumi config list '{key}'.");
        }

        return normalized;
    }

    var flutterNativeRedirectUris = RequireStringList("flutterNativeRedirectUris");
    var flutterWebCallbackUrls = RequireStringList("flutterWebCallbackUrls");
    var flutterWebLogoutUrls = RequireStringList("flutterWebLogoutUrls");
    var flutterWebOrigins = RequireStringList("flutterWebOrigins");
    var backendApiBaseUrls = RequireStringList("backendApiBaseUrls");

    var githubOwner = "polyphony-org";
    var githubRepository = "polyphony";

    var frontendBackendBaseUrl = config.Require("frontendBackendBaseUrl");
    var frontendAuth0Domain = auth0Config.Require("domain");

    var apiResourceServer = new ResourceServer("polyphony-api", new ResourceServerArgs
    {
        Name = "Polyphony API",
        Identifier = "https://api.polyphony.com",
        SigningAlg = "RS256",
        EnforcePolicies = false,
        SkipConsentForVerifiableFirstPartyClients = true,
        TokenLifetime = 3600,
    });

    var appResourceServer = new ResourceServer("polyphony-app", new ResourceServerArgs
    {
        Name = "Polyphony App",
        Identifier = "https://app.polyphony.com",
        SigningAlg = "RS256",
        EnforcePolicies = false,
        SkipConsentForVerifiableFirstPartyClients = true,
        TokenLifetime = 3600,
        AllowOfflineAccess = true,
    });

    var databaseConnection = new Connection("polyphony-database", new ConnectionArgs
    {
        Name = auth0DatabaseConnectionName,
        DisplayName = "Polyphony Users",
        Strategy = "auth0",
        ShowAsButton = false,
    });

    var webClient = new Client("polyphony-web", new ClientArgs
    {
        Name = "Polyphony Web",
        Description = "Flutter web SPA for Polyphony",
        AppType = "spa",
        OidcConformant = true,
        IsFirstParty = true,
        Callbacks = flutterWebCallbackUrls.ToArray(),
        AllowedLogoutUrls = flutterWebLogoutUrls.ToArray(),
        WebOrigins = flutterWebOrigins.ToArray(),
        AllowedOrigins = flutterWebOrigins.ToArray(),
        GrantTypes =
        [
            "authorization_code",
        ],
        ResourceServerIdentifier = appResourceServer.Identifier,
    });

    var nativeClient = new Client("polyphony-native", new ClientArgs
    {
        Name = "Polyphony Native",
        Description = "Flutter client for Polyphony",
        AppType = "native",
        OidcConformant = true,
        IsFirstParty = true,
        Callbacks = flutterNativeRedirectUris.ToArray(),
        AllowedLogoutUrls = flutterNativeRedirectUris.ToArray(),
        RefreshToken = new ClientRefreshTokenArgs
        {
            RotationType = "rotating",
            ExpirationType = "expiring",
            InfiniteTokenLifetime = false,
            TokenLifetime = 60 * 60 * 24 * 30 * 3, // 90 days
            IdleTokenLifetime = 60 * 60 * 24 * 30, // 30 days
            Leeway = 60, // 1 minute
        },
        GrantTypes =
        [
            "authorization_code",
            "refresh_token",
        ],
        ResourceServerIdentifier = appResourceServer.Identifier,
    });

    var apiMachineClient = new Client("polyphony-api-service", new ClientArgs
    {
        Name = "Polyphony Service",
        Description = "Machine-to-machine client for backend API automation",
        AppType = "non_interactive",
        OidcConformant = true,
        IsFirstParty = true,
        GrantTypes = ["client_credentials"],
        AllowedOrigins = backendApiBaseUrls.ToArray(),
    });

    var databaseConnectionClients = new ConnectionClients("polyphony-database-clients", new ConnectionClientsArgs
    {
        ConnectionId = databaseConnection.Id,
        EnabledClients =
        [
            webClient.ClientId,
            nativeClient.ClientId,
        ],
    });

    var apiClientGrant = new ClientGrant("polyphony-api-client-grant", new ClientGrantArgs
    {
        ClientId = apiMachineClient.ClientId,
        Audience = apiResourceServer.Identifier,
        AllowAllScopes = false,
        Scopes = [],
    });

    var webClientGrant = new ClientGrant("polyphony-web-client-grant", new ClientGrantArgs
    {
        ClientId = webClient.ClientId,
        Audience = appResourceServer.Identifier,
        AllowAllScopes = false,
        Scopes = [],
    });

    var nativeClientGrant = new ClientGrant("polyphony-native-client-grant", new ClientGrantArgs
    {
        ClientId = nativeClient.ClientId,
        Audience = appResourceServer.Identifier,
        AllowAllScopes = false,
        Scopes = [],
    });

    var frontendBackendBaseUrlVariable = new Pulumi.Github.ActionsVariable("frontend-backend-base-url", new Pulumi.Github.ActionsVariableArgs
    {
        Repository = githubRepository,
        VariableName = "POLYPHONY_BACKEND_BASE_URL",
        Value = frontendBackendBaseUrl,
    });

    var frontendAuth0DomainVariable = new Pulumi.Github.ActionsVariable("frontend-auth0-domain", new Pulumi.Github.ActionsVariableArgs
    {
        Repository = githubRepository,
        VariableName = "AUTH0_DOMAIN",
        Value = frontendAuth0Domain,
    });

    return new Dictionary<string, object?>
    {
        ["githubOwner"] = githubOwner,
        ["githubRepository"] = githubRepository,
        ["auth0ApiIdentifier"] = apiResourceServer.Identifier,
        ["auth0ApiId"] = apiResourceServer.Id,
        ["auth0AppIdentifier"] = appResourceServer.Identifier,
        ["auth0AppId"] = appResourceServer.Id,
        ["auth0DatabaseConnectionName"] = databaseConnection.Name,
        ["auth0DatabaseConnectionId"] = databaseConnection.Id,
        ["flutterWebClientId"] = webClient.ClientId,
        ["flutterNativeClientId"] = nativeClient.ClientId,
        ["backendM2mClientId"] = apiMachineClient.ClientId,
        ["apiClientGrantId"] = apiClientGrant.Id,
        ["databaseConnectionClientsId"] = databaseConnectionClients.Id,
        ["frontendBackendBaseUrlVariableName"] = frontendBackendBaseUrlVariable.VariableName,
        ["frontendAuth0DomainVariableName"] = frontendAuth0DomainVariable.VariableName,
    };
});