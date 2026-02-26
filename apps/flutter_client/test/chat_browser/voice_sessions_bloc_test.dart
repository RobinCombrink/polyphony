import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/voice_sessions_bloc.dart";

import "../entity_seeder.dart";
import "test_doubles/chat_repository_fakes.dart";

void main() {
  final fixture = EntitySeeder().chatApiFixture();

  blocTest<VoiceSessionsBloc, VoiceSessionsState>(
    "loads participants for selected channel",
    build: () => VoiceSessionsBloc(
      voiceSessionRepo: FakeVoiceSessionRepository(fixture: fixture),
    ),
    act: (bloc) => bloc.add(
      LoadVoiceSessionsRequested(
        baseUrl: "http://127.0.0.1:5067",
        channelId: fixture.listedChannel.id,
      ),
    ),
    expect: () => <Matcher>[
      isA<VoiceSessionsLoadingState>(),
      isA<VoiceSessionsLoadedState>().having(
        (state) => state.voiceSessions.length,
        "voice sessions length",
        1,
      ),
    ],
  );

  blocTest<VoiceSessionsBloc, VoiceSessionsState>(
    "emits validation failed on missing channel",
    build: () => VoiceSessionsBloc(
      voiceSessionRepo: FakeVoiceSessionRepository(fixture: fixture),
    ),
    act: (bloc) {
      bloc.add(LoadVoiceSessionsRequested(
        baseUrl: "http://127.0.0.1:5067",
        channelId: fixture.listedChannel.id,
      ));
      bloc.add(const JoinVoiceSessionRequested(
        baseUrl: "http://127.0.0.1:5067",
        channelId: "",
      ));
    },
    expect: () => <Matcher>[
      isA<VoiceSessionsLoadingState>(),
      isA<VoiceSessionsLoadedState>(),
      isA<VoiceSessionsValidationFailedState>().having(
        (state) => state.issue,
        "issue",
        VoiceSessionsValidationIssue.channelSelectionRequired,
      ),
    ],
  );

  blocTest<VoiceSessionsBloc, VoiceSessionsState>(
    "leaves voice and reloads empty list",
    build: () => VoiceSessionsBloc(
      voiceSessionRepo: FakeVoiceSessionRepository(fixture: fixture),
    ),
    act: (bloc) {
      bloc.add(LoadVoiceSessionsRequested(
        baseUrl: "http://127.0.0.1:5067",
        channelId: fixture.listedChannel.id,
      ));
      bloc.add(LeaveVoiceSessionRequested(
        baseUrl: "http://127.0.0.1:5067",
        channelId: fixture.listedChannel.id,
      ));
    },
    expect: () => <Matcher>[
      isA<VoiceSessionsLoadingState>(),
      isA<VoiceSessionsLoadedState>(),
      isA<VoiceSessionsLoadingState>(),
      isA<VoiceSessionsLoadedState>().having(
        (state) => state.voiceSessions,
        "voice sessions",
        isEmpty,
      ),
    ],
  );
}