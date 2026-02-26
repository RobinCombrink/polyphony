using Pulumi;
using Pulumi.Auth0;

return await Deployment.RunAsync(() =>
{
    var config = new Pulumi.Config();

    var apiIdentifier = "https://polyphony.com";
    var flutterNativeRedirectUri = config.Require("flutterNativeRedirectUri");
    var backendApiBaseUrl = config.Require("backendApiBaseUrl");

    var resourceServer = new ResourceServer("polyphony-api", new ResourceServerArgs
    {
        Name = "Polyphony API",
        Identifier = apiIdentifier,
        SigningAlg = "RS256",
        EnforcePolicies = false,
        SkipConsentForVerifiableFirstPartyClients = true,
        TokenLifetime = 3600,
    });

    var nativeClient = new Client("polyphony-native", new ClientArgs
    {
        Name = "Polyphony Native",
        Description = "Flutter client for Polyphony",
        AppType = "native",
        OidcConformant = true,
        Callbacks = new[] { flutterNativeRedirectUri },
        AllowedLogoutUrls = new[] { flutterNativeRedirectUri },
        GrantTypes = new[]
        {
            "authorization_code",
            "refresh_token",
        },
    });

    var machineClient = new Client("polyphony-service", new ClientArgs
    {
        Name = "Polyphony Service",
        Description = "Machine-to-machine client for backend automation",
        AppType = "non_interactive",
        OidcConformant = true,
        GrantTypes = new[] { "client_credentials" },
        AllowedOrigins = new[] { backendApiBaseUrl },
    });

    return new Dictionary<string, object?>
    {
        ["auth0ApiIdentifier"] = resourceServer.Identifier,
        ["auth0ApiId"] = resourceServer.Id,
        ["flutterNativeClientId"] = nativeClient.ClientId,
        ["backendM2mClientId"] = machineClient.ClientId,
    };
});