part of "authentication_bloc.dart";

sealed class AuthenticationEvent {
  const AuthenticationEvent();
}

final class AuthenticationLoginRequested extends AuthenticationEvent {
  const AuthenticationLoginRequested({required this.bearerToken});

  final String bearerToken;
}

final class AuthenticationLogoutRequested extends AuthenticationEvent {
  const AuthenticationLogoutRequested();
}
