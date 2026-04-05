import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/shared/auth/authentication_profile_service.dart";
import "package:polyphony_flutter_client/shared/auth/authentication_session_service.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

part "authentication_event.dart";
part "authentication_state.dart";

class AuthenticationBloc
    extends Bloc<AuthenticationEvent, AuthenticationState> {
  AuthenticationBloc({
    required AuthenticationProfileService profileService,
    required AuthenticationSessionService sessionService,
  })  : _profileService = profileService,
        _sessionService = sessionService,
        super(const AuthenticationUnauthenticatedState()) {
    on<AuthenticationSessionRestoreRequested>(
      _onAuthenticationSessionRestoreRequested,
    );
    on<AuthenticationSignInRequested>(_onAuthenticationSignInRequested);
    on<AuthenticationLoginRequested>(_onAuthenticationLoginRequested);
    on<AuthenticationLogoutRequested>(_onAuthenticationLogoutRequested);
  }

  final AuthenticationProfileService _profileService;
  final AuthenticationSessionService _sessionService;
  var _hasRestoredSession = false;

  Future<void> _onAuthenticationSessionRestoreRequested(
    AuthenticationSessionRestoreRequested event,
    Emitter<AuthenticationState> emit,
  ) async {
    if (_hasRestoredSession) {
      return;
    }

    _hasRestoredSession = true;
    emit(const AuthenticationAuthenticatingState());

    final restoreResult = await _sessionService.restoreAccessToken();

    switch (restoreResult) {
      case Ok(:final value?) when value.isNotEmpty:
        final bearerToken = value;
        await _authenticateBearerToken(
          emit: emit,
          bearerToken: bearerToken,
        );
      case Ok<String?>(value: String()):
        emit(const AuthenticationUnauthenticatedState());
        return;
      case Ok(value: null):
        emit(const AuthenticationUnauthenticatedState());
        return;
      case Error<String?>(:final error):
        emit(AuthenticationFailedState(error: error));
        return;
    }
  }

  Future<void> _onAuthenticationSignInRequested(
    AuthenticationSignInRequested event,
    Emitter<AuthenticationState> emit,
  ) async {
    emit(const AuthenticationAuthenticatingState());

    final signInResult =
        await _sessionService.signIn(loginHint: event.loginHint);

    switch (signInResult) {
      case Ok<String>(:final value):
        if (value.isEmpty) {
          emit(const AuthenticationUnauthenticatedState());
          return;
        }

        await _authenticateBearerToken(
          emit: emit,
          bearerToken: value,
        );
      case Error<String>(:final error)
          when error is AuthenticationSignInRedirectInProgressException:
        emit(const AuthenticationUnauthenticatedState());
      case Error<String>(:final error):
        emit(AuthenticationFailedState(error: error));
    }
  }

  Future<void> _onAuthenticationLoginRequested(
    AuthenticationLoginRequested event,
    Emitter<AuthenticationState> emit,
  ) async {
    emit(const AuthenticationAuthenticatingState());
    await _authenticateBearerToken(
      emit: emit,
      bearerToken: event.bearerToken,
    );
  }

  Future<void> _onAuthenticationLogoutRequested(
    AuthenticationLogoutRequested event,
    Emitter<AuthenticationState> emit,
  ) async {
    final signOutResult = await _sessionService.signOut();
    if (signOutResult case Error<void>(:final error)) {
      emit(AuthenticationFailedState(error: error));
      return;
    }

    emit(const AuthenticationUnauthenticatedState());
  }

  Future<void> _authenticateBearerToken({
    required Emitter<AuthenticationState> emit,
    required String bearerToken,
  }) async {
    final trimmedToken = bearerToken.trim();
    if (trimmedToken.isEmpty) {
      emit(const AuthenticationUnauthenticatedState());
      return;
    }

    final meResult = await _profileService.getMe(bearerToken: trimmedToken);

    switch (meResult) {
      case Ok(:final value):
        final trimmedUserId = value.userId.trim();
        if (trimmedUserId.isEmpty) {
          emit(
            AuthenticationFailedState(
              error:
                  Exception("Authenticated profile response has empty userId."),
            ),
          );
          return;
        }

        emit(
          AuthenticationAuthenticatedState(
            metadata: AuthenticationMetadata(
              userId: trimmedUserId,
              bearerToken: trimmedToken,
            ),
          ),
        );
      case Error(:final error):
        emit(AuthenticationFailedState(error: error));
    }
  }
}
