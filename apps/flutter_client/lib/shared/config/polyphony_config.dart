abstract final class PolyphonyConfig {
  static const backendBaseUrl = String.fromEnvironment(
    "POLYPHONY_BACKEND_BASE_URL",
    defaultValue: "http://127.0.0.1:5067",
  );

  static const auth0Domain = String.fromEnvironment(
    "AUTH0_DOMAIN",
    defaultValue: "dev-polyphony.eu.auth0.com",
  );

  static const auth0NativeClientId = String.fromEnvironment(
    "AUTH0_NATIVE_CLIENT_ID",
    defaultValue: "PPpiiFNzm71rBt6WoF0J4h6mZvlr08yK",
  );

  static const auth0WebClientId = String.fromEnvironment(
    "AUTH0_WEB_CLIENT_ID",
    defaultValue: "XtYoQKoUZvWeYtqmNEoIUByjYlSNGjgd",
  );

  static const auth0Audience = String.fromEnvironment(
    "AUTH0_AUDIENCE",
    defaultValue: "https://app.polyphony.com",
  );

  static const auth0Scopes = String.fromEnvironment(
    "AUTH0_SCOPES",
    defaultValue: "openid profile email",
  );

  static const auth0MobileRedirectUri = String.fromEnvironment(
    "AUTH0_MOBILE_REDIRECT_URI",
    defaultValue: "polyphony://auth/callback",
  );

  static const auth0DesktopRedirectUri = String.fromEnvironment(
    "AUTH0_DESKTOP_REDIRECT_URI",
    defaultValue: "http://localhost:4000",
  );

  static const sentryDsn = String.fromEnvironment(
    "SENTRY_FRONTEND_DSN",
  );

  static const sentryEnvironment = String.fromEnvironment(
    "SENTRY_ENVIRONMENT",
    defaultValue: "development",
  );

  static const sentryRelease = String.fromEnvironment(
    "SENTRY_RELEASE",
  );

  static const sentryEnabled = bool.fromEnvironment(
    "SENTRY_ENABLED",
    defaultValue: true,
  );

  static const sentryTracesSampleRateRaw = String.fromEnvironment(
    "SENTRY_TRACES_SAMPLE_RATE",
    defaultValue: "1.0",
  );

  static double sentryTracesSampleRate() {
    return double.tryParse(sentryTracesSampleRateRaw) ?? 1.0;
  }
}
