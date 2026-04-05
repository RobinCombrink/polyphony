part of "authentication_bloc.dart";

sealed class AuthenticationState {
  const AuthenticationState();
}

final class AuthenticationUnauthenticatedState extends AuthenticationState {
  const AuthenticationUnauthenticatedState();
}

final class AuthenticationFailedState extends AuthenticationState {
  const AuthenticationFailedState({required this.error});

  final Exception error;
}

final class AuthenticationAuthenticatingState extends AuthenticationState {
  const AuthenticationAuthenticatingState();
}

final class AuthenticationAuthenticatedState extends AuthenticationState {
  const AuthenticationAuthenticatedState({
    required this.metadata,
  });

  final AuthenticationMetadata metadata;
}

final class AuthenticationMetadata {
  const AuthenticationMetadata({
    required this.userId,
    required this.bearerToken,
  });

  final String userId;
  final String bearerToken;
}
