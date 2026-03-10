import "package:polyphony_flutter_client/shared/auth/access_token_provider.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

class AuthenticationSessionService {
  const AuthenticationSessionService({
    required AccessTokenProvider accessTokenProvider,
    required bool isWeb,
  })  : _accessTokenProvider = accessTokenProvider,
        _isWeb = isWeb;

  final AccessTokenProvider _accessTokenProvider;
  final bool _isWeb;

  Future<Result<String?>> restoreAccessToken() async {
    final persistedTokenResult =
        await _accessTokenProvider.getPersistedAccessToken();

    switch (persistedTokenResult) {
      case Ok<String?>(:final value):
        final trimmedToken = value?.trim();
        if (trimmedToken != null && trimmedToken.isNotEmpty) {
          return Ok<String?>(trimmedToken);
        }

        if (!_isWeb) {
          return const Ok<String?>(null);
        }

        final signInResult = await _accessTokenProvider.getAccessToken();
        return switch (signInResult) {
          Ok<String>(:final value) => Ok<String?>(value.trim()),
          Error<String>(:final error) when _isRedirectInProgressError(error) =>
            const Ok<String?>(null),
          Error<String>(:final error) => Error<String?>(error),
        };
      case Error<String?>(:final error):
        return Error<String?>(error);
    }
  }

  Future<Result<String>> signIn({String? loginHint}) async {
    final signInResult = await _accessTokenProvider.getAccessToken(
      loginHint: loginHint,
    );

    return switch (signInResult) {
      Ok<String>(:final value) => Ok<String>(value.trim()),
      Error<String>(:final error) when _isRedirectInProgressError(error) =>
        Error<String>(const AuthenticationSignInRedirectInProgressException()),
      Error<String>(:final error) => Error<String>(error),
    };
  }

  Future<Result<void>> signOut() {
    return _accessTokenProvider.clearPersistedSession();
  }

  bool _isRedirectInProgressError(Exception error) {
    return error.toString().contains("Redirecting to Auth0 for sign in.");
  }
}

final class AuthenticationSignInRedirectInProgressException
    implements Exception {
  const AuthenticationSignInRedirectInProgressException();

  @override
  String toString() {
    return "Authentication redirect in progress.";
  }
}
