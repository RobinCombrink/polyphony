import "dart:convert";
import "dart:math";

import "package:auth0_flutter/auth0_flutter.dart";
import "package:auth0_flutter/auth0_flutter_web.dart";
import "package:crypto/crypto.dart";
import "package:flutter/foundation.dart";
import "package:flutter_web_auth_2/flutter_web_auth_2.dart";
import "package:http/http.dart" as http;
import "package:polyphony_flutter_client/shared/auth/access_token_provider.dart";
import "package:polyphony_flutter_client/shared/auth/refresh_token_store.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

class Auth0TokenProvider implements AccessTokenProvider {
  Auth0TokenProvider({
    required http.Client httpClient,
    required RefreshTokenStore refreshTokenStore,
    required String domain,
    required String clientId,
    required String audience,
    required String scopes,
    required String mobileRedirectUri,
    required String desktopRedirectUri,
  }) : _delegate = kIsWeb
            ? Auth0WebTokenProvider(
                domain: domain,
                clientId: clientId,
                audience: audience,
                scopes: scopes,
              )
            : Auth0NativeTokenProvider(
                httpClient: httpClient,
                refreshTokenStore: refreshTokenStore,
                domain: domain,
                clientId: clientId,
                audience: audience,
                scopes: scopes,
                mobileRedirectUri: mobileRedirectUri,
                desktopRedirectUri: desktopRedirectUri,
              );

  final AccessTokenProvider _delegate;

  @override
  Future<Result<String?>> getPersistedAccessToken() {
    return _delegate.getPersistedAccessToken();
  }

  @override
  Future<Result<String>> getAccessToken({String? loginHint}) {
    return _delegate.getAccessToken(loginHint: loginHint);
  }

  @override
  Future<Result<void>> clearPersistedSession() {
    return _delegate.clearPersistedSession();
  }
}

final class Auth0WebTokenProvider implements AccessTokenProvider {
  Auth0WebTokenProvider({
    required String domain,
    required String clientId,
    required String audience,
    required String scopes,
  })  : _audience = _normalizedAudience(audience),
        _scopes = _normalizedScopes(scopes, includeOfflineAccess: false),
        _redirectUrl = _resolvedWebRedirectUrl(),
        _auth0Web = Auth0Web(
          domain,
          clientId,
          redirectUrl: _resolvedWebRedirectUrl(),
          cacheLocation: CacheLocation.localStorage,
        );

  final Auth0Web _auth0Web;
  final String? _audience;
  final Set<String> _scopes;
  final String _redirectUrl;

  @override
  Future<Result<String?>> getPersistedAccessToken() async {
    try {
      final credentials = await _auth0Web.onLoad(
        audience: _audience,
        scopes: _scopes,
        useRefreshTokens: false,
      );

      if (credentials == null) {
        return const Ok<String?>(null);
      }

      return _tokenResultOrNull(credentials.accessToken);
    } on Exception catch (error) {
      return Error<String?>(error);
    }
  }

  @override
  Future<Result<String>> getAccessToken({String? loginHint}) async {
    try {
      final normalizedLoginHint = _normalizedLoginHint(loginHint);
      await _auth0Web.loginWithRedirect(
        audience: _audience,
        scopes: _scopes,
        redirectUrl: _redirectUrl,
        parameters: <String, String>{
          if (normalizedLoginHint != null) "login_hint": normalizedLoginHint,
        },
      );

      return Error<String>(Exception("Redirecting to Auth0 for sign in."));
    } on Exception catch (error) {
      return Error<String>(error);
    }
  }

  @override
  Future<Result<void>> clearPersistedSession() async {
    return const Ok<void>(null);
  }
}

final class Auth0NativeTokenProvider implements AccessTokenProvider {
  Auth0NativeTokenProvider({
    required http.Client httpClient,
    required RefreshTokenStore refreshTokenStore,
    required String domain,
    required String clientId,
    required String audience,
    required String scopes,
    required String mobileRedirectUri,
    required String desktopRedirectUri,
  }) : _delegate = _isDesktopPlatform()
            ? _DesktopAuth0TokenProvider(
                httpClient: httpClient,
                refreshTokenStore: refreshTokenStore,
                domain: domain,
                clientId: clientId,
                audience: audience,
                scopes: scopes,
                desktopRedirectUri: desktopRedirectUri,
              )
            : _Auth0SdkNativeTokenProvider(
                domain: domain,
                clientId: clientId,
                audience: audience,
                scopes: scopes,
                mobileRedirectUri: mobileRedirectUri,
              );

  final AccessTokenProvider _delegate;

  static bool _isDesktopPlatform() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows => true,
      TargetPlatform.linux => true,
      TargetPlatform.fuchsia => true,
      TargetPlatform.android => false,
      TargetPlatform.iOS => false,
      TargetPlatform.macOS => false,
    };
  }

  @override
  Future<Result<String?>> getPersistedAccessToken() {
    return _delegate.getPersistedAccessToken();
  }

  @override
  Future<Result<String>> getAccessToken({String? loginHint}) {
    return _delegate.getAccessToken(loginHint: loginHint);
  }

  @override
  Future<Result<void>> clearPersistedSession() {
    return _delegate.clearPersistedSession();
  }
}

final class _Auth0SdkNativeTokenProvider implements AccessTokenProvider {
  _Auth0SdkNativeTokenProvider({
    required String domain,
    required String clientId,
    required String audience,
    required String scopes,
    required String mobileRedirectUri,
  })  : _auth0 = Auth0(domain, clientId),
        _audience = _normalizedAudience(audience),
        _scopes = _normalizedScopes(scopes, includeOfflineAccess: true),
        _mobileRedirectUri = mobileRedirectUri;

  final Auth0 _auth0;
  final String? _audience;
  final Set<String> _scopes;
  final String _mobileRedirectUri;

  @override
  Future<Result<String?>> getPersistedAccessToken() async {
    try {
      final hasValidCredentials =
          await _auth0.credentialsManager.hasValidCredentials();
      if (!hasValidCredentials) {
        return const Ok<String?>(null);
      }

      final credentials = await _auth0.credentialsManager.credentials();
      final accessToken = credentials.accessToken.trim();
      if (accessToken.isEmpty) {
        return const Ok<String?>(null);
      }

      return Ok<String?>(accessToken);
    } on Exception catch (error) {
      return Error<String?>(error);
    }
  }

  @override
  Future<Result<String>> getAccessToken({String? loginHint}) async {
    try {
      final normalizedLoginHint = _normalizedLoginHint(loginHint);
      final credentials = await _auth0.webAuthentication().login(
        audience: _audience,
        scopes: _scopes,
        redirectUrl: _mobileRedirectUri,
        parameters: <String, String>{
          if (normalizedLoginHint != null) "login_hint": normalizedLoginHint,
        },
      );

      return _tokenResult(credentials.accessToken);
    } on Exception catch (error) {
      return Error<String>(error);
    }
  }

  @override
  Future<Result<void>> clearPersistedSession() async {
    try {
      await _auth0.credentialsManager.clearCredentials();
      return const Ok<void>(null);
    } on Exception catch (error) {
      return Error<void>(error);
    }
  }
}

final class _DesktopAuth0TokenProvider implements AccessTokenProvider {
  _DesktopAuth0TokenProvider({
    required http.Client httpClient,
    required RefreshTokenStore refreshTokenStore,
    required String domain,
    required String clientId,
    required String audience,
    required String scopes,
    required String desktopRedirectUri,
  })  : _httpClient = httpClient,
        _refreshTokenStore = refreshTokenStore,
        _domain = domain,
        _clientId = clientId,
        _audience = _normalizedAudience(audience),
        _scopes = _normalizedScopes(scopes, includeOfflineAccess: true),
        _desktopRedirectUri = desktopRedirectUri;

  final http.Client _httpClient;
  final RefreshTokenStore _refreshTokenStore;
  final String _domain;
  final String _clientId;
  final String? _audience;
  final Set<String> _scopes;
  final String _desktopRedirectUri;

  @override
  Future<Result<String?>> getPersistedAccessToken() async {
    final refreshTokenResult = await _refreshTokenStore.readRefreshToken();
    switch (refreshTokenResult) {
      case Ok<String?>(:final value):
        final refreshToken = value;
        if (refreshToken == null || refreshToken.trim().isEmpty) {
          return const Ok<String?>(null);
        }

        final refreshedAccessTokenResult =
            await _exchangeRefreshTokenForAccessToken(refreshToken);
        switch (refreshedAccessTokenResult) {
          case Ok<String>(:final value):
            return Ok<String?>(value);
          case Error<String>(:final error):
            return Error<String?>(error);
        }
      case Error<String?>(:final error):
        return Error<String?>(error);
    }
  }

  @override
  Future<Result<String>> getAccessToken({String? loginHint}) async {
    if (_domain.trim().isEmpty) {
      return Error<String>(
        Exception("Missing AUTH0_DOMAIN configuration."),
      );
    }

    final callbackUri = Uri.parse(_desktopRedirectUri);
    final state = _randomString(32);
    final codeVerifier = _randomString(96);
    final codeChallenge = _codeChallengeFromVerifier(codeVerifier);
    final authorizeUri = _authorizeUri(
      redirectUri: _desktopRedirectUri,
      scopes: _scopes,
      audience: _audience,
      state: state,
      codeChallenge: codeChallenge,
      prompt: null,
      loginHint: _normalizedLoginHint(loginHint),
    );

    try {
      final callbackResult = await FlutterWebAuth2.authenticate(
        url: authorizeUri.toString(),
        callbackUrlScheme: _callbackUrlScheme(callbackUri),
        options: const FlutterWebAuth2Options(useWebview: false),
      );

      final callbackResultUri = Uri.parse(callbackResult);
      final callbackParameters = _callbackParameters(callbackResultUri);

      final oauthError = callbackParameters["error"];
      if (oauthError != null && oauthError.trim().isNotEmpty) {
        final oauthErrorDescription = callbackParameters["error_description"];
        final errorMessage = oauthErrorDescription == null ||
                oauthErrorDescription.trim().isEmpty
            ? oauthError
            : "$oauthError: $oauthErrorDescription";
        return Error<String>(
          Exception("OAuth authorization failed: $errorMessage"),
        );
      }

      final returnedState = callbackParameters["state"];
      if (returnedState == null || returnedState != state) {
        return Error<String>(Exception("Invalid OAuth state returned."));
      }

      final authorizationCode = callbackParameters["code"];
      if (authorizationCode == null || authorizationCode.trim().isEmpty) {
        return Error<String>(Exception("Missing authorization code."));
      }

      final tokenResponse = await _httpClient.post(
        Uri.parse("${_issuerBaseUrl()}/oauth/token"),
        headers: const <String, String>{
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: <String, String>{
          "grant_type": "authorization_code",
          "client_id": _clientId,
          "code": authorizationCode,
          "redirect_uri": _desktopRedirectUri,
          "code_verifier": codeVerifier,
          "scope": _scopes.join(" "),
          if (_audience != null) "audience": _audience,
        },
      );

      final tokenBody =
          jsonDecode(tokenResponse.body) as Map<String, dynamic>? ??
              const <String, dynamic>{};

      if (tokenResponse.statusCode < 200 || tokenResponse.statusCode >= 300) {
        return Error<String>(
          Exception(
            "Failed to exchange authorization code: ${tokenResponse.statusCode} ${tokenResponse.body}",
          ),
        );
      }

      final accessToken = tokenBody["access_token"] as String?;
      if (accessToken == null || accessToken.trim().isEmpty) {
        return Error<String>(
          Exception("Auth0 returned an empty access token."),
        );
      }

      final refreshToken = _extractRefreshToken(tokenBody);
      if (refreshToken == null) {
        return Error<String>(
          Exception(
            "Auth0 did not return refresh_token in desktop login response. Verify AUTH0_NATIVE_CLIENT_ID is a Native application and offline access is enabled.",
          ),
        );
      }

      final persistResult = await _refreshTokenStore.writeRefreshToken(
        refreshToken,
      );
      if (persistResult case Error<void>(:final error)) {
        return Error<String>(error);
      }

      return _tokenResult(accessToken);
    } on Exception catch (error) {
      return Error<String>(error);
    }
  }

  @override
  Future<Result<void>> clearPersistedSession() {
    return _refreshTokenStore.deleteRefreshToken();
  }

  Future<Result<String>> _exchangeRefreshTokenForAccessToken(
    String refreshToken,
  ) async {
    try {
      final tokenResponse = await _httpClient.post(
        Uri.parse("${_issuerBaseUrl()}/oauth/token"),
        headers: const <String, String>{
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: <String, String>{
          "grant_type": "refresh_token",
          "client_id": _clientId,
          "refresh_token": refreshToken,
          if (_audience != null) "audience": _audience,
        },
      );

      final tokenBody =
          jsonDecode(tokenResponse.body) as Map<String, dynamic>? ??
              const <String, dynamic>{};

      if (tokenResponse.statusCode < 200 || tokenResponse.statusCode >= 300) {
        await _refreshTokenStore.deleteRefreshToken();
        return Error<String>(
          Exception(
            "Failed to refresh access token: ${tokenResponse.statusCode} ${tokenResponse.body}",
          ),
        );
      }

      final accessToken = tokenBody["access_token"] as String?;
      if (accessToken == null || accessToken.trim().isEmpty) {
        await _refreshTokenStore.deleteRefreshToken();
        return Error<String>(
          Exception("Auth0 returned an empty access token during refresh."),
        );
      }

      final persistResult = await _persistRefreshToken(tokenBody);
      if (persistResult case Error<void>(:final error)) {
        return Error<String>(error);
      }

      return _tokenResult(accessToken);
    } on Exception catch (error) {
      return Error<String>(error);
    }
  }

  Future<Result<void>> _persistRefreshToken(Map<String, dynamic> tokenBody) {
    final refreshToken = _extractRefreshToken(tokenBody);
    if (refreshToken == null) {
      return Future<Result<void>>.value(const Ok<void>(null));
    }

    return _refreshTokenStore.writeRefreshToken(refreshToken);
  }

  String? _extractRefreshToken(Map<String, dynamic> tokenBody) {
    final tokenValue = tokenBody["refresh_token"];
    if (tokenValue is! String) {
      return null;
    }

    final trimmedToken = tokenValue.trim();
    if (trimmedToken.isEmpty) {
      return null;
    }

    return trimmedToken;
  }

  Uri _authorizeUri({
    required String redirectUri,
    required Set<String> scopes,
    required String? audience,
    required String state,
    required String codeChallenge,
    required String? prompt,
    required String? loginHint,
  }) {
    final queryParameters = <String, String>{
      "response_type": "code",
      "client_id": _clientId,
      "redirect_uri": redirectUri,
      "scope": scopes.join(" "),
      "state": state,
      "code_challenge": codeChallenge,
      "code_challenge_method": "S256",
      if (audience != null) "audience": audience,
      if (prompt != null && prompt.trim().isNotEmpty) "prompt": prompt,
      if (loginHint != null && loginHint.trim().isNotEmpty)
        "login_hint": loginHint,
    };

    return Uri.parse("${_issuerBaseUrl()}/authorize").replace(
      queryParameters: queryParameters,
    );
  }

  String _callbackUrlScheme(Uri callbackUri) {
    if (callbackUri.scheme != "http" || callbackUri.host != "localhost") {
      throw Exception(
        "Desktop redirect URI must use http://localhost:{port}.",
      );
    }

    if (!callbackUri.hasPort) {
      throw Exception(
        "Desktop redirect URI must include an explicit localhost port.",
      );
    }

    return "${callbackUri.scheme}://${callbackUri.host}:${callbackUri.port}";
  }

  String _issuerBaseUrl() {
    final trimmedDomain = _domain.trim();
    if (trimmedDomain.startsWith("http://") ||
        trimmedDomain.startsWith("https://")) {
      return trimmedDomain;
    }

    return "https://$trimmedDomain";
  }

  Map<String, String> _callbackParameters(Uri callbackResultUri) {
    final fragment = callbackResultUri.fragment;
    final fragmentParameters = fragment.contains("=")
        ? Uri.splitQueryString(fragment)
        : <String, String>{};

    return <String, String>{
      ...fragmentParameters,
      ...callbackResultUri.queryParameters,
    };
  }
}

Result<String> _tokenResult(String accessToken) {
  final trimmedAccessToken = accessToken.trim();

  if (trimmedAccessToken.isEmpty) {
    return Error<String>(Exception("Auth0 returned an empty access token."));
  }

  return Ok<String>(trimmedAccessToken);
}

Result<String?> _tokenResultOrNull(String accessToken) {
  final tokenResult = _tokenResult(accessToken);
  return switch (tokenResult) {
    Ok<String>(:final value) => Ok<String?>(value),
    Error<String>(:final error) => Error<String?>(error),
  };
}

String? _normalizedAudience(String audience) {
  final trimmedAudience = audience.trim();
  return trimmedAudience.isEmpty ? null : trimmedAudience;
}

Set<String> _normalizedScopes(
  String scopes, {
  required bool includeOfflineAccess,
}) {
  return scopes
      .split(" ")
      .map((scope) => scope.trim())
      .followedBy([
        "openid",
        "profile",
        "email",
        if (includeOfflineAccess) "offline_access",
      ])
      .where((scope) => scope.isNotEmpty)
      .toSet();
}

String _resolvedWebRedirectUrl() {
  return Uri.base.replace(query: "", fragment: "").toString();
}

String? _normalizedLoginHint(String? loginHint) {
  if (loginHint == null) {
    return null;
  }

  final trimmedLoginHint = loginHint.trim();
  return trimmedLoginHint.isEmpty ? null : trimmedLoginHint;
}

String _codeChallengeFromVerifier(String codeVerifier) {
  final digest = sha256.convert(utf8.encode(codeVerifier));
  return _base64UrlNoPadding(digest.bytes);
}

String _randomString(int length) {
  const charset =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~";
  final random = Random.secure();
  return List<String>.generate(
    length,
    (_) => charset[random.nextInt(charset.length)],
  ).join();
}

String _base64UrlNoPadding(List<int> value) {
  return base64Url.encode(value).replaceAll("=", "");
}
