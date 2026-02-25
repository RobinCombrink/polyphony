import "dart:convert";
import "dart:math";

import "package:crypto/crypto.dart";
import "package:flutter/foundation.dart";
import "package:flutter_web_auth_2/flutter_web_auth_2.dart";
import "package:http/http.dart" as http;
import "package:polyphony_flutter_client/shared/auth/access_token_provider.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

class Auth0TokenProvider implements AccessTokenProvider {
  Auth0TokenProvider({
    required http.Client httpClient,
    required String domain,
    required String clientId,
    required String audience,
    required String scopes,
    required String mobileRedirectUri,
    required String desktopRedirectUri,
    required String webRedirectPath,
  })  : _domain = domain,
        _httpClient = httpClient,
        _clientId = clientId,
        _audience = audience,
        _scopes = scopes,
        _mobileRedirectUri = mobileRedirectUri,
        _desktopRedirectUri = desktopRedirectUri,
        _webRedirectPath = webRedirectPath;

  final String _domain;
  final http.Client _httpClient;
  final String _clientId;
  final String _audience;
  final String _scopes;
  final String _mobileRedirectUri;
  final String _desktopRedirectUri;
  final String _webRedirectPath;

  @override
  Future<Result<String>> getAccessToken() async {
    if (_domain.trim().isEmpty) {
      return Error<String>(
        Exception("Missing AUTH0_DOMAIN configuration."),
      );
    }

    final normalizedScopes = _normalizedScopes();
    final normalizedAudience = _normalizedAudience();
    final redirectUri = _redirectUriForCurrentPlatform();
    final callbackUri = Uri.parse(redirectUri);
    final state = _randomString(32);
    final codeVerifier = _randomString(96);
    final codeChallenge = _codeChallengeFromVerifier(codeVerifier);
    final authorizeUri = _authorizeUri(
      redirectUri: redirectUri,
      scopes: normalizedScopes,
      audience: normalizedAudience,
      state: state,
      codeChallenge: codeChallenge,
    );

    try {
      final callbackResult = await FlutterWebAuth2.authenticate(
        url: authorizeUri.toString(),
        callbackUrlScheme: _callbackUrlSchemeForCurrentPlatform(callbackUri),
        options: _authOptions(),
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
            Exception("OAuth authorization failed: $errorMessage"));
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
          "redirect_uri": redirectUri,
          "code_verifier": codeVerifier,
          if (normalizedAudience != null) "audience": normalizedAudience,
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
            Exception("Auth0 returned an empty access token."));
      }

      return _tokenResult(accessToken);
    } on Exception catch (error) {
      return Error<String>(error);
    }
  }

  Result<String> _tokenResult(String accessToken) {
    final trimmedAccessToken = accessToken.trim();

    if (trimmedAccessToken.isEmpty) {
      return Error<String>(Exception("Auth0 returned an empty access token."));
    }

    return Ok<String>(trimmedAccessToken);
  }

  String? _normalizedAudience() {
    final trimmedAudience = _audience.trim();
    return trimmedAudience.isEmpty ? null : trimmedAudience;
  }

  Set<String> _normalizedScopes() {
    final configuredScopes = _scopes
        .split(" ")
        .map((scope) => scope.trim())
        .followedBy(["openid", "profile", "email"])
        .where((scope) => scope.isNotEmpty)
        .toSet();

    return configuredScopes;
  }

  String _redirectUriForCurrentPlatform() {
    if (kIsWeb) {
      final normalizedPath = _webRedirectPath.startsWith("/")
          ? _webRedirectPath.substring(1)
          : _webRedirectPath;
      return Uri.base.resolve(normalizedPath).toString();
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.windows => _desktopRedirectUri,
      TargetPlatform.linux => _desktopRedirectUri,
      TargetPlatform.android => _mobileRedirectUri,
      TargetPlatform.iOS => _mobileRedirectUri,
      TargetPlatform.macOS => _mobileRedirectUri,
      TargetPlatform.fuchsia => _desktopRedirectUri,
    };
  }

  FlutterWebAuth2Options _authOptions() {
    final isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux);

    if (isDesktop) {
      return const FlutterWebAuth2Options(useWebview: false);
    }

    return const FlutterWebAuth2Options();
  }

  Uri _authorizeUri({
    required String redirectUri,
    required Set<String> scopes,
    required String? audience,
    required String state,
    required String codeChallenge,
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
    };

    return Uri.parse("${_issuerBaseUrl()}/authorize").replace(
      queryParameters: queryParameters,
    );
  }

  String _issuerBaseUrl() {
    final trimmedDomain = _domain.trim();
    if (trimmedDomain.startsWith("http://") ||
        trimmedDomain.startsWith("https://")) {
      return trimmedDomain;
    }

    return "https://$trimmedDomain";
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

  String _callbackUrlSchemeForCurrentPlatform(Uri callbackUri) {
    final isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux);

    if (!isDesktop) {
      return callbackUri.scheme;
    }

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
}
