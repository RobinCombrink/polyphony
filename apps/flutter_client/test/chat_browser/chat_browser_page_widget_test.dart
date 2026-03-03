import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
import "package:polyphony_flutter_client/features/channels/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/home/presentation/home_page_widget.dart";
import "package:polyphony_flutter_client/features/identity/bloc/profile_bloc.dart";
import "package:polyphony_flutter_client/features/messages/bloc/messages_bloc.dart";
import "package:polyphony_flutter_client/features/servers/bloc/server_members_bloc.dart";
import "package:polyphony_flutter_client/features/servers/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/features/voice_sessions/bloc/voice_sessions_bloc.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";
import "package:provider/provider.dart";

import "../entity_seeder.dart";
import "test_doubles/chat_repository_fakes.dart";

class _RecordingServerMembersBloc extends ServerMembersBloc {
  _RecordingServerMembersBloc({
    required super.serverRepo,
    required super.profileRepo,
  });

  final recordedEvents = <ServerMembersEvent>[];

  @override
  void add(ServerMembersEvent event) {
    recordedEvents.add(event);
    super.add(event);
  }
}

void main() {
  testWidgets(
    "loads server users when selected server changes",
    (tester) async {
      final fixture = EntitySeeder().chatApiFixture();
      final serverRepo = FakeServerRepository(fixture: fixture);
      final channelRepo = FakeChannelRepository(fixture: fixture);
      final messageRepo = FakeMessageRepository(fixture: fixture);
      final profileRepo = FakeProfileRepository(
        userId: fixture.ownerUserId,
      );
      final textSessionRepo = FakeTextSessionRepository(fixture: fixture);
      final voiceSessionRepo = FakeVoiceSessionRepository(fixture: fixture);
      final voiceRuntimeService = FakeVoiceRuntimeService();
      final messageRuntimeService = FakeMessageRuntimeService();

      final authenticationBloc = AuthenticationBloc()
        ..add(const AuthenticationLoginRequested(bearerToken: "test-token"));
      final serversBloc = ServersBloc(serverRepo: serverRepo);
      final channelsBloc = ChannelsBloc(channelRepo: channelRepo);
      final messagesBloc = MessagesBloc(
        messageRepo: messageRepo,
        profileRepo: profileRepo,
        textSessionRepo: textSessionRepo,
        messageRuntimeService: messageRuntimeService,
      );
      final profileBloc = ProfileBloc(profileRepo: profileRepo);
      final serverMembersBloc = _RecordingServerMembersBloc(
        serverRepo: serverRepo,
        profileRepo: profileRepo,
      );
      final voiceSessionsBloc = VoiceSessionsBloc(
        voiceSessionRepo: voiceSessionRepo,
        voiceRuntimeService: voiceRuntimeService,
        profileRepo: profileRepo,
      );

      addTearDown(authenticationBloc.close);
      addTearDown(serversBloc.close);
      addTearDown(channelsBloc.close);
      addTearDown(messagesBloc.close);
      addTearDown(profileBloc.close);
      addTearDown(serverMembersBloc.close);
      addTearDown(voiceSessionsBloc.close);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<PreferencesStore>(
              create: (_) => InMemoryPreferencesStore(),
            ),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider<AuthenticationBloc>.value(value: authenticationBloc),
              BlocProvider<ServersBloc>.value(value: serversBloc),
              BlocProvider<ChannelsBloc>.value(value: channelsBloc),
              BlocProvider<MessagesBloc>.value(value: messagesBloc),
              BlocProvider<ProfileBloc>.value(value: profileBloc),
              BlocProvider<ServerMembersBloc>.value(value: serverMembersBloc),
              BlocProvider<VoiceSessionsBloc>.value(value: voiceSessionsBloc),
            ],
            child: const MaterialApp(home: HomePageWidget()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      serverMembersBloc.recordedEvents.clear();
      serversBloc.add(
        SelectServerRequested(serverId: fixture.listedServer.id),
      );
      await tester.pump();

      final loadEvents = serverMembersBloc.recordedEvents
          .whereType<LoadServerMembersRequested>()
          .toList();

      expect(loadEvents, hasLength(1));
      expect(loadEvents.single.serverId, fixture.listedServer.id);
    },
  );
}
