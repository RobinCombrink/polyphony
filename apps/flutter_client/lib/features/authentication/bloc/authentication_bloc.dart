import "package:flutter_bloc/flutter_bloc.dart";

part "authentication_event.dart";
part "authentication_state.dart";

class AuthenticationBloc extends Bloc<AuthenticationEvent, AuthenticationState>
    implements AuthenticationStateSource {
  AuthenticationBloc() : super(const AuthenticationUnauthenticatedState()) {
    on<AuthenticationLoginRequested>(_onAuthenticationLoginRequested);
    on<AuthenticationLogoutRequested>(_onAuthenticationLogoutRequested);
  }

  @override
  AuthenticationState get currentAuthState => state;

  void _onAuthenticationLoginRequested(
    AuthenticationLoginRequested event,
    Emitter<AuthenticationState> emit,
  ) {
    final trimmedToken = event.bearerToken.trim();

    if (trimmedToken.isEmpty) {
      emit(const AuthenticationUnauthenticatedState(
        issue: AuthenticationIssue.tokenRequired,
      ));
      return;
    }

    emit(const AuthenticationAuthenticatingState());
    emit(AuthenticationAuthenticatedState(bearerToken: trimmedToken));
  }

  void _onAuthenticationLogoutRequested(
    AuthenticationLogoutRequested event,
    Emitter<AuthenticationState> emit,
  ) {
    emit(const AuthenticationUnauthenticatedState(
      issue: AuthenticationIssue.signedOut,
    ));
  }
}
