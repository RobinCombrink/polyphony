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
      profileRepo: FakeProfileRepository(
        userId: fixture.ownerUserId,
        displayNamesByUserId: const <String, String?>{
          "auth0|local_user": "Local User",
        },
      ),
    ),
    act: (bloc) => bloc.add(
      LoadVoiceSessionsRequested(
        channelId: fixture.listedChannel.id,
      ),
    ),
    expect: () => <Matcher>[
      isA<VoiceSessionsLoadedState>()
          .having(
            (state) => state.selectedChannelId,
            "channel id",
            fixture.listedChannel.id,
          )
          .having(
            (state) =>
                state.participants.map((participant) => participant.userId),
            "participant user ids",
            contains(fixture.connectedVoiceSession.participantUserId),
          ),
    ],
  );

  blocTest<VoiceSessionsBloc, VoiceSessionsState>(
    "emits validation failed on missing channel",
    build: () => VoiceSessionsBloc(
      voiceSessionRepo: FakeVoiceSessionRepository(fixture: fixture),
      voiceRuntimeService: FakeVoiceRuntimeService(),
      profileRepo: FakeProfileRepository(userId: fixture.ownerUserId),
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
      profileRepo: FakeProfileRepository(userId: fixture.ownerUserId),
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

  blocTest<VoiceSessionsBloc, VoiceSessionsState>(
    "set self muted updates mute state",
    build: () => VoiceSessionsBloc(
      voiceSessionRepo: FakeVoiceSessionRepository(fixture: fixture),
      voiceRuntimeService: FakeVoiceRuntimeService(),
      profileRepo: FakeProfileRepository(userId: fixture.ownerUserId),
    ),
    act: (bloc) {
      bloc.add(LoadVoiceSessionsRequested(
        channelId: fixture.listedChannel.id,
      ));
      bloc.add(ConnectVoiceSessionRequested(
        channelId: fixture.listedChannel.id,
      ));
      bloc.add(const SetSelfMutedRequested(muted: true));
      bloc.add(const SetSelfMutedRequested(muted: false));
    },
    expect: () => <Matcher>[
      isA<VoiceSessionsLoadedState>(),
      isA<VoiceSessionsLoadingState>(),
      isA<VoiceSessionsLoadedState>().having(
        (state) => state.isSelfMuted,
        "is self muted",
        false,
      ),
      isA<VoiceSessionsLoadedState>()
          .having(
            (state) => state.isSelfMuted,
            "is self muted",
            true,
          )
          .having(
            (state) => state.participants
                .firstWhere(
                  (participant) =>
                      participant.userId ==
                      fixture.connectedVoiceSession.participantUserId,
                )
                .isMuted,
            "self participant muted",
            true,
          ),
      isA<VoiceSessionsLoadedState>()
          .having(
            (state) => state.isSelfMuted,
            "is self muted",
            false,
          )
          .having(
            (state) => state.participants
                .firstWhere(
                  (participant) =>
                      participant.userId ==
                      fixture.connectedVoiceSession.participantUserId,
                )
                .isMuted,
            "self participant unmuted",
            false,
          ),
    ],
  );

  blocTest<VoiceSessionsBloc, VoiceSessionsState>(
    "set self deafened enables mute and toggles deafen state",
    build: () => VoiceSessionsBloc(
      voiceSessionRepo: FakeVoiceSessionRepository(fixture: fixture),
      voiceRuntimeService: FakeVoiceRuntimeService(),
      profileRepo: FakeProfileRepository(userId: fixture.ownerUserId),
    ),
    act: (bloc) {
      bloc
        ..add(LoadVoiceSessionsRequested(
          channelId: fixture.listedChannel.id,
        ))
        ..add(ConnectVoiceSessionRequested(
          channelId: fixture.listedChannel.id,
        ))
        ..add(const SetSelfDeafenedRequested(deafened: true))
        ..add(const SetSelfDeafenedRequested(deafened: false));
    },
    expect: () => <Matcher>[
      isA<VoiceSessionsLoadedState>(),
      isA<VoiceSessionsLoadingState>(),
      isA<VoiceSessionsLoadedState>(),
      isA<VoiceSessionsLoadedState>()
          .having(
            (state) => state.isSelfDeafened,
            "is self deafened",
            true,
          )
          .having(
            (state) => state.isSelfMuted,
            "is self muted",
            true,
          ),
      isA<VoiceSessionsLoadedState>()
          .having(
            (state) => state.isSelfDeafened,
            "is self deafened",
            false,
          )
          .having(
            (state) => state.isSelfMuted,
            "is self muted",
            false,
          ),
    ],
  );

  blocTest<VoiceSessionsBloc, VoiceSessionsState>(
    "set self muted false while deafened undeafens and unmutes",
    build: () => VoiceSessionsBloc(
      voiceSessionRepo: FakeVoiceSessionRepository(fixture: fixture),
      voiceRuntimeService: FakeVoiceRuntimeService(),
      profileRepo: FakeProfileRepository(userId: fixture.ownerUserId),
    ),
    act: (bloc) {
      bloc
        ..add(LoadVoiceSessionsRequested(
          channelId: fixture.listedChannel.id,
        ))
        ..add(ConnectVoiceSessionRequested(
          channelId: fixture.listedChannel.id,
        ))
        ..add(const SetSelfDeafenedRequested(deafened: true))
        ..add(const SetSelfMutedRequested(muted: false));
    },
    expect: () => <Matcher>[
      isA<VoiceSessionsLoadedState>(),
      isA<VoiceSessionsLoadingState>(),
      isA<VoiceSessionsLoadedState>(),
      isA<VoiceSessionsLoadedState>()
          .having(
            (state) => state.isSelfDeafened,
            "is self deafened",
            true,
          )
          .having(
            (state) => state.isSelfMuted,
            "is self muted",
            true,
          ),
      isA<VoiceSessionsLoadedState>()
          .having(
            (state) => state.isSelfDeafened,
            "is self deafened",
            false,
          )
          .having(
            (state) => state.isSelfMuted,
            "is self muted",
            false,
          ),
    ],
  );

  blocTest<VoiceSessionsBloc, VoiceSessionsState>(
    "switching voice channels clears stale participants from previous channel",
    build: () => VoiceSessionsBloc(
      voiceSessionRepo: FakeVoiceSessionRepository(fixture: fixture),
      voiceRuntimeService: FakeVoiceRuntimeService(),
      profileRepo: FakeProfileRepository(
        userId: fixture.ownerUserId,
        displayNamesByUserId: const <String, String?>{
          "auth0|local_user": "Local User",
        },
      ),
    ),
    act: (bloc) {
      bloc.add(LoadVoiceSessionsRequested(channelId: fixture.listedChannel.id));
      bloc.add(
          ConnectVoiceSessionRequested(channelId: fixture.listedChannel.id));
      bloc.add(
          LoadVoiceSessionsRequested(channelId: fixture.createdChannel.id));
      bloc.add(
          ConnectVoiceSessionRequested(channelId: fixture.createdChannel.id));
    },
    expect: () => <Matcher>[
      isA<VoiceSessionsLoadedState>(),
      isA<VoiceSessionsLoadingState>(),
      isA<VoiceSessionsLoadedState>(),
      isA<VoiceSessionsLoadedState>(),
      isA<VoiceSessionsLoadingState>(),
      isA<VoiceSessionsLoadedState>()
          .having(
            (state) => state.connectedChannelId,
            "connected channel id",
            fixture.createdChannel.id,
          )
          .having(
            (state) => state.participantsByChannelId[fixture.listedChannel.id],
            "previous channel participants",
            isEmpty,
          )
          .having(
            (state) => state.participantsByChannelId[fixture.createdChannel.id]
                ?.map((participant) => participant.userId)
                .toList(),
            "new channel participants",
            contains(fixture.connectedVoiceSession.participantUserId),
          ),
    ],
  );
}
