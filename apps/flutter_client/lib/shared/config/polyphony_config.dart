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
    defaultValue: "3QEwnOrRK5qAFqjNJvXWdPJDhLz1p0yZ",
  );

  static const auth0WebClientId = String.fromEnvironment(
    "AUTH0_WEB_CLIENT_ID",
    defaultValue: "pyTVsVOWzcOK85LQfL4Ulwpeft4XpSqW",
  );

  static const auth0Audience = String.fromEnvironment(
    "AUTH0_AUDIENCE",
    defaultValue: "https://polyphony.com",
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
}
