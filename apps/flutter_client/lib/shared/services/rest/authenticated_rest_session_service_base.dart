import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
import "package:polyphony_flutter_client/shared/config/polyphony_config.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

abstract base class AuthenticatedRestSessionServiceBase {
  AuthenticatedRestSessionServiceBase({
    required AuthenticationStateSource authenticationStateSource,
  }) : _authenticationStateSource = authenticationStateSource;

  final AuthenticationStateSource _authenticationStateSource;

  String get baseUrl => PolyphonyConfig.backendBaseUrl;

  Future<Result<T>> executeAuthenticated<T>(
    Future<Result<T>> Function(String baseUrl) operation,
  ) {
    if (_authenticationStateSource.currentAuthState
        is! AuthenticationAuthenticatedState) {
      return Future<Result<T>>.value(
        Error<T>(Exception("Auth token is required.")),
      );
    }

    return operation(baseUrl);
  }
}
