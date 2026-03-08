import "package:bloc_test/bloc_test.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
import "package:polyphony_flutter_client/features/authentication/presentation/authentication_gate_widget.dart";
import "package:polyphony_flutter_client/features/identity/bloc/profile_bloc.dart";
import "package:polyphony_flutter_client/shared/auth/access_token_provider.dart";
import "package:polyphony_flutter_client/shared/auth/authentication_profile_service.dart";
import "package:polyphony_flutter_client/shared/auth/authentication_session_service.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";
import "package:provider/provider.dart";

import "../entity_seeder.dart";
import "../test_doubles/chat_repository_fakes.dart";

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
  final fixture = EntitySeeder().chatApiFixture();

  group("Feature: Service health and identity", () {
    group("Rule: Authenticated identity is readable", () {
      testWidgets(
        "Scenario: Authentication gate restores session intent on startup",
        (tester) async {
          final authenticationBloc = _RecordingAuthenticationBloc();
          addTearDown(authenticationBloc.close);

          await tester.pumpWidget(
            MultiProvider(
              providers: [
                Provider<PreferencesStore>(
                  create: (_) => InMemoryPreferencesStore(),
                ),
                BlocProvider<AuthenticationBloc>.value(
                  value: authenticationBloc,
                ),
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

      blocTest<ProfileBloc, ProfileState>(
        "Scenario: First identity view has no display name yet",
        build: () => ProfileBloc(
          profileRepo: FakeProfileRepository(userId: fixture.ownerUserId),
          currentUserId: fixture.ownerUserId,
        ),
        act: (bloc) => bloc.add(const LoadProfileRequested()),
        expect: () => <Matcher>[
          isA<ProfileLoadingState>(),
          isA<ProfileLoadedState>()
              .having((state) => state.userId, "user id", fixture.ownerUserId)
              .having((state) => state.displayName, "display name", isNull),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        "Scenario: Authenticated user can view identity details",
        build: () => ProfileBloc(
          profileRepo: FakeProfileRepository(
            userId: fixture.ownerUserId,
            displayNamesByUserId: <String, String?>{
              fixture.ownerUserId: "Polyphony User",
            },
          ),
          currentUserId: fixture.ownerUserId,
        ),
        act: (bloc) => bloc.add(const LoadProfileRequested()),
        expect: () => <Matcher>[
          isA<ProfileLoadingState>(),
          isA<ProfileLoadedState>()
              .having((state) => state.userId, "user id", fixture.ownerUserId)
              .having((state) => state.displayName, "display name",
                  "Polyphony User"),
        ],
      );
    });
  });
}
