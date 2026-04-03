import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/voice_sessions/bloc/voice_sessions_bloc.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";

import "../entity_seeder.dart";
import "../test_doubles/chat_repository_fakes.dart";

void main() {
  final fixture = EntitySeeder().chatApiFixture();

  group("Feature: Voice sessions", () {
    group("Rule: Authenticated user connects to compatible channels", () {
      blocTest<VoiceSessionsBloc, VoiceSessionsState>(
        "Scenario: Authenticated user can join an existing voice channel",
        build: () => VoiceSessionsBloc(
          voiceSessionRepo: FakeVoiceSessionRepository(fixture: fixture),
          voiceRuntimeService: FakeVoiceRuntimeService(),
          profileRepo: FakeProfileRepository(userId: fixture.ownerUserId),
        ),
        act: (bloc) => bloc
          ..add(
            LoadVoiceSessionsRequested(
                channelId: fixture.listedVoiceChannel.id),
          )
          ..add(
            ConnectVoiceSessionRequested(
                channelId: fixture.listedVoiceChannel.id),
          ),
        expect: () => <Matcher>[
          isA<VoiceSessionsLoadedState>(),
          isA<VoiceSessionsLoadingState>(),
          isA<VoiceSessionsLoadedState>().having(
            (state) => state.activeConnection?.channelId,
            "active channel id",
            fixture.listedVoiceChannel.id,
          ),
        ],
      );

      blocTest<VoiceSessionsBloc, VoiceSessionsState>(
        "Scenario: Connecting to voice in a missing channel reports that it does not exist",
        build: () => VoiceSessionsBloc(
          voiceSessionRepo: FakeVoiceSessionRepository(
            fixture: fixture,
            connectError: Exception("Channel does not exist"),
          ),
          voiceRuntimeService: FakeVoiceRuntimeService(),
          profileRepo: FakeProfileRepository(userId: fixture.ownerUserId),
        ),
        act: (bloc) => bloc
          ..add(
            LoadVoiceSessionsRequested(
                channelId: fixture.listedVoiceChannel.id),
          )
          ..add(
            const ConnectVoiceSessionRequested(
                channelId: ChannelId("missing-channel")),
          ),
        expect: () => <Matcher>[
          isA<VoiceSessionsLoadedState>(),
          isA<VoiceSessionsLoadingState>(),
          isA<VoiceSessionsExceptionState>().having(
            (state) => state.error,
            "error",
            isA<Exception>(),
          ),
        ],
      );
    });
  });
}
