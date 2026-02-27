import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/voice_sessions_bloc.dart";

import "../entity_seeder.dart";
import "test_doubles/chat_repository_fakes.dart";

void main() {
  final fixture = EntitySeeder().chatApiFixture();

  blocTest<VoiceSessionsBloc, VoiceSessionsState>(
    "loads selected channel context",
    build: () => VoiceSessionsBloc(
      voiceSessionRepo: FakeVoiceSessionRepository(fixture: fixture),
      voiceRuntimeService: FakeVoiceRuntimeService(),
    ),
    act: (bloc) => bloc.add(
      LoadVoiceSessionsRequested(
        channelId: fixture.listedChannel.id,
      ),
    ),
    expect: () => <Matcher>[
      isA<VoiceSessionsLoadedState>().having(
        (state) => state.channelId,
        "channel id",
        fixture.listedChannel.id,
      ),
    ],
  );

  blocTest<VoiceSessionsBloc, VoiceSessionsState>(
    "emits validation failed on missing channel",
    build: () => VoiceSessionsBloc(
      voiceSessionRepo: FakeVoiceSessionRepository(fixture: fixture),
      voiceRuntimeService: FakeVoiceRuntimeService(),
    ),
    act: (bloc) {
      bloc.add(LoadVoiceSessionsRequested(
        channelId: fixture.listedChannel.id,
      ));
      bloc.add(const ConnectVoiceSessionRequested(
        channelId: "",
      ));
    },
    expect: () => <Matcher>[
      isA<VoiceSessionsLoadedState>(),
      isA<VoiceSessionsValidationFailedState>().having(
        (state) => state.issue,
        "issue",
        VoiceSessionsValidationIssue.channelSelectionRequired,
      ),
    ],
  );

  blocTest<VoiceSessionsBloc, VoiceSessionsState>(
    "disconnect clears active connection",
    build: () => VoiceSessionsBloc(
      voiceSessionRepo: FakeVoiceSessionRepository(fixture: fixture),
      voiceRuntimeService: FakeVoiceRuntimeService(),
    ),
    act: (bloc) {
      bloc.add(LoadVoiceSessionsRequested(
        channelId: fixture.listedChannel.id,
      ));
      bloc.add(ConnectVoiceSessionRequested(
        channelId: fixture.listedChannel.id,
      ));
      bloc.add(DisconnectVoiceSessionRequested(
        channelId: fixture.listedChannel.id,
      ));
    },
    expect: () => <Matcher>[
      isA<VoiceSessionsLoadedState>(),
      isA<VoiceSessionsLoadingState>(),
      isA<VoiceSessionsLoadedState>().having(
        (state) => state.activeConnection,
        "active connection",
        isNotNull,
      ),
      isA<VoiceSessionsLoadingState>(),
      isA<VoiceSessionsLoadedState>().having(
        (state) => state.activeConnection,
        "active connection",
        isNull,
      ),
    ],
  );
}
