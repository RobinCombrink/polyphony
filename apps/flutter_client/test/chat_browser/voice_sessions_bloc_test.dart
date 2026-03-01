import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/voice_sessions_bloc.dart";

import "../entity_seeder.dart";
import "test_doubles/chat_repository_fakes.dart";

void main() {
  final fixture = EntitySeeder().chatApiFixture();
  late FakeVoiceRuntimeService speakingRuntimeService;

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
        channelId: fixture.listedVoiceChannel.id,
      ),
    ),
    expect: () => <Matcher>[
      isA<VoiceSessionsLoadedState>()
          .having(
            (state) => state.selectedChannelId,
            "channel id",
            fixture.listedVoiceChannel.id,
          )
          .having(
            (state) =>
                state.participants.map((participant) => participant.userId),
            "participant user ids",
            isEmpty,
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
        channelId: fixture.listedVoiceChannel.id,
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
        channelId: fixture.listedVoiceChannel.id,
      ));
      bloc.add(ConnectVoiceSessionRequested(
        channelId: fixture.listedVoiceChannel.id,
      ));
      bloc.add(DisconnectVoiceSessionRequested(
        channelId: fixture.listedVoiceChannel.id,
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
        channelId: fixture.listedVoiceChannel.id,
      ));
      bloc.add(ConnectVoiceSessionRequested(
        channelId: fixture.listedVoiceChannel.id,
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
          channelId: fixture.listedVoiceChannel.id,
        ))
        ..add(ConnectVoiceSessionRequested(
          channelId: fixture.listedVoiceChannel.id,
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
          channelId: fixture.listedVoiceChannel.id,
        ))
        ..add(ConnectVoiceSessionRequested(
          channelId: fixture.listedVoiceChannel.id,
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
    "updates participant speaking state from runtime events",
    build: () {
      speakingRuntimeService = FakeVoiceRuntimeService();

      return VoiceSessionsBloc(
        voiceSessionRepo: FakeVoiceSessionRepository(fixture: fixture),
        voiceRuntimeService: speakingRuntimeService,
        profileRepo: FakeProfileRepository(userId: fixture.ownerUserId),
      );
    },
    act: (bloc) async {
      bloc
        ..add(LoadVoiceSessionsRequested(
          channelId: fixture.listedVoiceChannel.id,
        ))
        ..add(ConnectVoiceSessionRequested(
          channelId: fixture.listedVoiceChannel.id,
        ));

      await Future<void>.delayed(Duration.zero);

      speakingRuntimeService.emitSpeakingParticipantUserIds(
        <String>{fixture.connectedVoiceSession.participantUserId},
      );

      await Future<void>.delayed(Duration.zero);
    },
    expect: () => <Matcher>[
      isA<VoiceSessionsLoadedState>(),
      isA<VoiceSessionsLoadingState>(),
      isA<VoiceSessionsLoadedState>(),
      isA<VoiceSessionsLoadedState>().having(
        (state) => state.participants
            .firstWhere(
              (participant) =>
                  participant.userId ==
                  fixture.connectedVoiceSession.participantUserId,
            )
            .isSpeaking,
        "self participant speaking",
        true,
      ),
    ],
  );

  blocTest<VoiceSessionsBloc, VoiceSessionsState>(
    "updates participant list from runtime participant stream",
    build: () {
      speakingRuntimeService = FakeVoiceRuntimeService(
        initialParticipantUserIds: <String>{
          fixture.connectedVoiceSession.participantUserId,
        },
      );

      return VoiceSessionsBloc(
        voiceSessionRepo: FakeVoiceSessionRepository(fixture: fixture),
        voiceRuntimeService: speakingRuntimeService,
        profileRepo: FakeProfileRepository(
          userId: fixture.ownerUserId,
          displayNamesByUserId: const <String, String?>{
            "auth0|u2": "Remote User",
          },
        ),
      );
    },
    act: (bloc) async {
      bloc
        ..add(LoadVoiceSessionsRequested(
          channelId: fixture.listedVoiceChannel.id,
        ))
        ..add(ConnectVoiceSessionRequested(
          channelId: fixture.listedVoiceChannel.id,
        ));

      await Future<void>.delayed(Duration.zero);

      speakingRuntimeService.emitParticipantUserIds(
        <String>{
          fixture.connectedVoiceSession.participantUserId,
          "auth0|u2",
        },
      );

      await Future<void>.delayed(Duration.zero);
    },
    expect: () => <Matcher>[
      isA<VoiceSessionsLoadedState>(),
      isA<VoiceSessionsLoadingState>(),
      isA<VoiceSessionsLoadedState>(),
      isA<VoiceSessionsLoadedState>().having(
        (state) => state.participants.map((participant) => participant.userId),
        "participant user ids",
        containsAll(<String>[
          fixture.connectedVoiceSession.participantUserId,
          "auth0|u2",
        ]),
      ),
    ],
  );

  blocTest<VoiceSessionsBloc, VoiceSessionsState>(
    "set self video enabled updates camera state",
    build: () => VoiceSessionsBloc(
      voiceSessionRepo: FakeVoiceSessionRepository(fixture: fixture),
      voiceRuntimeService: FakeVoiceRuntimeService(),
      profileRepo: FakeProfileRepository(userId: fixture.ownerUserId),
    ),
    act: (bloc) {
      bloc
        ..add(LoadVoiceSessionsRequested(
          channelId: fixture.listedVoiceChannel.id,
        ))
        ..add(ConnectVoiceSessionRequested(
          channelId: fixture.listedVoiceChannel.id,
        ))
        ..add(const SetSelfVideoEnabledRequested(enabled: true))
        ..add(const SetSelfVideoEnabledRequested(enabled: false));
    },
    expect: () => <Matcher>[
      isA<VoiceSessionsLoadedState>(),
      isA<VoiceSessionsLoadingState>(),
      isA<VoiceSessionsLoadedState>(),
      isA<VoiceSessionsLoadedState>().having(
        (state) => state.isSelfVideoEnabled,
        "is self video enabled",
        true,
      ),
      isA<VoiceSessionsLoadedState>().having(
        (state) => state.isSelfVideoEnabled,
        "is self video enabled",
        false,
      ),
    ],
  );

  blocTest<VoiceSessionsBloc, VoiceSessionsState>(
    "updates participant video tracks from runtime stream",
    build: () {
      speakingRuntimeService = FakeVoiceRuntimeService(
        initialParticipantUserIds: <String>{
          fixture.connectedVoiceSession.participantUserId,
        },
      );

      return VoiceSessionsBloc(
        voiceSessionRepo: FakeVoiceSessionRepository(fixture: fixture),
        voiceRuntimeService: speakingRuntimeService,
        profileRepo: FakeProfileRepository(userId: fixture.ownerUserId),
      );
    },
    act: (bloc) async {
      final videoTrackToken = Object();

      bloc
        ..add(LoadVoiceSessionsRequested(
          channelId: fixture.listedVoiceChannel.id,
        ))
        ..add(ConnectVoiceSessionRequested(
          channelId: fixture.listedVoiceChannel.id,
        ));

      await Future<void>.delayed(Duration.zero);

      speakingRuntimeService.emitParticipantVideoTracks(
        <String, Object>{
          fixture.connectedVoiceSession.participantUserId: videoTrackToken,
        },
      );

      await Future<void>.delayed(Duration.zero);
    },
    expect: () => <Matcher>[
      isA<VoiceSessionsLoadedState>(),
      isA<VoiceSessionsLoadingState>(),
      isA<VoiceSessionsLoadedState>(),
      isA<VoiceSessionsLoadedState>().having(
        (state) => state.participantVideoTracks
            .containsKey(fixture.connectedVoiceSession.participantUserId),
        "contains self participant video track",
        true,
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
      bloc.add(
          LoadVoiceSessionsRequested(channelId: fixture.listedVoiceChannel.id));
      bloc.add(ConnectVoiceSessionRequested(
          channelId: fixture.listedVoiceChannel.id));
      bloc.add(LoadVoiceSessionsRequested(
          channelId: fixture.createdVoiceChannel.id));
      bloc.add(ConnectVoiceSessionRequested(
          channelId: fixture.createdVoiceChannel.id));
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
            fixture.createdVoiceChannel.id,
          )
          .having(
            (state) =>
                state.participantsByChannelId[fixture.listedVoiceChannel.id],
            "previous channel participants",
            isEmpty,
          )
          .having(
            (state) => state
                .participantsByChannelId[fixture.createdVoiceChannel.id]
                ?.map((participant) => participant.userId)
                .toList(),
            "new channel participants",
            contains(fixture.connectedVoiceSession.participantUserId),
          ),
    ],
  );
}
