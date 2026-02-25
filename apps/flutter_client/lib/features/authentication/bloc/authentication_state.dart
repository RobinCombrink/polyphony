part of "authentication_bloc.dart";

sealed class AuthenticationState {
  const AuthenticationState();
}

enum AuthenticationIssue {
  tokenRequired,
  signedOut,
}

final class AuthenticationUnauthenticatedState extends AuthenticationState {
  const AuthenticationUnauthenticatedState({this.issue});

  final AuthenticationIssue? issue;
}

final class AuthenticationAuthenticatingState extends AuthenticationState {
  const AuthenticationAuthenticatingState();
}

final class AuthenticationAuthenticatedState extends AuthenticationState {
  const AuthenticationAuthenticatedState({
    required this.bearerToken,
  });

  final String bearerToken;
}

abstract interface class AuthenticationStateSource {
  AuthenticationState get currentAuthState;
}
