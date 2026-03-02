import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
import "package:polyphony_flutter_client/features/authentication/presentation/authentication_gate_widget.dart";
import "package:polyphony_flutter_client/shared/auth/access_token_provider.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:provider/provider.dart";

class _RecordingAuthenticationBloc extends AuthenticationBloc {
  final recordedEvents = <AuthenticationEvent>[];

  @override
  void add(AuthenticationEvent event) {
    recordedEvents.add(event);
  }
}

class _FakeAccessTokenProvider implements AccessTokenProvider {
  const _FakeAccessTokenProvider({
    required this.persistedTokenResult,
  });

  final Result<String?> persistedTokenResult;

  @override
  Future<Result<String?>> getPersistedAccessToken() async {
    return persistedTokenResult;
  }

  @override
  Future<Result<String>> getAccessToken() async {
    return Error<String>(Exception("Not used in this test."));
  }

  @override
  Future<Result<void>> clearPersistedSession() async {
    return const Ok<void>(null);
  }
}

void main() {
  testWidgets(
    "dispatches login from persisted token on native startup",
    (tester) async {
      final authenticationBloc = _RecordingAuthenticationBloc();
      addTearDown(authenticationBloc.close);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AccessTokenProvider>(
              create: (_) => const _FakeAccessTokenProvider(
                persistedTokenResult: Ok<String?>("persisted-access-token"),
              ),
            ),
            BlocProvider<AuthenticationBloc>.value(value: authenticationBloc),
          ],
          child: const MaterialApp(home: AuthenticationGateWidget()),
        ),
      );

      await tester.pump();

      expect(authenticationBloc.recordedEvents, hasLength(1));

      final loginEvent =
          authenticationBloc.recordedEvents.single as AuthenticationLoginRequested;

      expect(loginEvent.bearerToken, "persisted-access-token");
    },
  );
}