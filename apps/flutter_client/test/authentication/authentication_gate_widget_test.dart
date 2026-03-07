import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
import "package:polyphony_flutter_client/features/authentication/presentation/authentication_gate_widget.dart";
import "package:polyphony_flutter_client/shared/auth/access_token_provider.dart";
import "package:polyphony_flutter_client/shared/auth/authentication_profile_service.dart";
import "package:polyphony_flutter_client/shared/auth/authentication_session_service.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";
import "package:provider/provider.dart";

class _RecordingAuthenticationBloc extends AuthenticationBloc {
  _RecordingAuthenticationBloc()
      : super(
          profileService: _FakeAuthenticationProfileService(),
          sessionService: _FakeAuthenticationSessionService(),
        );

  final recordedEvents = <AuthenticationEvent>[];

  @override
  void add(AuthenticationEvent event) {
    recordedEvents.add(event);
  }
}

class _FakeAuthenticationProfileService extends AuthenticationProfileService {
  _FakeAuthenticationProfileService() : super(httpClient: http.Client());

  @override
  Future<Result<ApiMe>> getMe({required String bearerToken}) async {
    return const Ok<ApiMe>(
      ApiMe(
        userId: "test-user-id",
        displayName: null,
        issuer: "test",
      ),
    );
  }
}

class _FakeAuthenticationSessionService extends AuthenticationSessionService {
  _FakeAuthenticationSessionService()
      : super(
          accessTokenProvider: _NoopAccessTokenProvider(),
          isWeb: false,
        );
}

class _NoopAccessTokenProvider implements AccessTokenProvider {
  @override
  Future<Result<String?>> getPersistedAccessToken() async {
    return const Ok<String?>(null);
  }

  @override
  Future<Result<String>> getAccessToken({String? loginHint}) async {
    return Error<String>(Exception("Not used in test."));
  }

  @override
  Future<Result<void>> clearPersistedSession() async {
    return const Ok<void>(null);
  }
}

void main() {
  testWidgets(
    "dispatches restore intent on startup",
    (tester) async {
      final authenticationBloc = _RecordingAuthenticationBloc();
      addTearDown(authenticationBloc.close);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<PreferencesStore>(
              create: (_) => InMemoryPreferencesStore(),
            ),
            BlocProvider<AuthenticationBloc>.value(value: authenticationBloc),
          ],
          child: const MaterialApp(home: AuthenticationGateWidget()),
        ),
      );

      await tester.pump();

      expect(authenticationBloc.recordedEvents, hasLength(1));

      expect(
        authenticationBloc.recordedEvents.single,
        isA<AuthenticationSessionRestoreRequested>(),
      );
    },
  );
}
