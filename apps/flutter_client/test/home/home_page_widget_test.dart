import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
import "package:polyphony_flutter_client/features/channels/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/home/presentation/home_page_widget.dart";
import "package:polyphony_flutter_client/features/identity/bloc/profile_bloc.dart";
import "package:polyphony_flutter_client/features/messages/bloc/messages_bloc.dart";
import "package:polyphony_flutter_client/features/notifications/bloc/notification_center_bloc.dart";
import "package:polyphony_flutter_client/features/servers/bloc/server_members_bloc.dart";
import "package:polyphony_flutter_client/features/servers/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/features/settings/bloc/settings_bloc.dart";
import "package:polyphony_flutter_client/features/voice_sessions/bloc/voice_sessions_bloc.dart";
import "package:polyphony_flutter_client/shared/auth/access_token_provider.dart";
import "package:polyphony_flutter_client/shared/auth/authentication_profile_service.dart";
import "package:polyphony_flutter_client/shared/auth/authentication_session_service.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/repositories/notification_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/emote_service.dart";
import "package:polyphony_flutter_client/shared/services/link_preview_service.dart";
import "package:polyphony_flutter_client/shared/services/notification_badge_service.dart";
import "package:polyphony_flutter_client/shared/services/notification_runtime_service.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";
import "package:polyphony_flutter_client/shared/services/reaction_service.dart";
import "package:provider/provider.dart";

import "../entity_seeder.dart";
import "../test_doubles/chat_repository_fakes.dart";

class _RecordingServerMembersBloc extends ServerMembersBloc {
  _RecordingServerMembersBloc({
    required super.serverMemberRepo,
    required super.profileRepo,
    required super.friendRepo,
    required super.serverRepo,
  });

  final recordedEvents = <ServerMembersEvent>[];

  @override
  void add(ServerMembersEvent event) {
    recordedEvents.add(event);
    super.add(event);
  }
}

class _FakeAuthenticationProfileService extends AuthenticationProfileService {
  _FakeAuthenticationProfileService({required this.userId})
      : super(httpClient: http.Client());

  final UserId userId;

  @override
  Future<Result<ApiMe>> getMe({required String bearerToken}) async {
    return Ok<ApiMe>(
      ApiMe(
        userId: userId.value,
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

class _FakeNotificationRepository implements NotificationRepo {
  _FakeNotificationRepository({
    this.totalUnreadCount = 0,
  });

  final int totalUnreadCount;

  @override
  Future<Result<int>> getOne({
    required GetNotificationUnreadCountQuery query,
  }) async {
    return Ok<int>(totalUnreadCount);
  }
}

class _HomePageTestHarness {
  _HomePageTestHarness({
    int totalUnreadCount = 0,
    PreferencesStore? preferencesStore,
  })  : fixture = EntitySeeder().chatApiFixture(),
        _totalUnreadCount = totalUnreadCount,
        preferencesStore = preferencesStore ?? InMemoryPreferencesStore();

  final ChatApiFixture fixture;
  final int _totalUnreadCount;
  final PreferencesStore preferencesStore;

  late final _serverRepo = FakeServerRepository(fixture: fixture);
  late final _channelRepo = FakeChannelRepository(fixture: fixture);
  late final _messageRepo = FakeMessageRepository(fixture: fixture);
  late final _profileRepo = FakeProfileRepository(
    userId: fixture.ownerUserId,
    initialDisplayName: "Owner",
  );
  late final _textSessionRepo = FakeTextSessionRepository(fixture: fixture);
  late final _voiceSessionRepo = FakeVoiceSessionRepository(fixture: fixture);
  late final _voiceRuntimeService = FakeVoiceRuntimeService();
  late final _messageRuntimeService = FakeMessageRuntimeService();
  late final notificationRuntimeService = FakeNotificationRuntimeService();

  late final _authenticationBloc = AuthenticationBloc(
    profileService: _FakeAuthenticationProfileService(
      userId: fixture.ownerUserId,
    ),
    sessionService: _FakeAuthenticationSessionService(),
  )..add(const AuthenticationLoginRequested(bearerToken: "test-token"));

  late final serversBloc = ServersBloc(serverRepo: _serverRepo);
  late final channelsBloc = ChannelsBloc(channelRepo: _channelRepo);

  late final _messagesBloc = MessagesBloc(
    messageRepo: _messageRepo,
    profileRepo: _profileRepo,
    textSessionRepo: _textSessionRepo,
    messageRuntimeService: _messageRuntimeService,
  );

  late final _profileBloc = ProfileBloc(
    profileRepo: _profileRepo,
    currentUserId: fixture.ownerUserId,
  );

  late final serverMembersBloc = _RecordingServerMembersBloc(
    serverMemberRepo: FakeServerMemberRepository(fixture: fixture),
    profileRepo: _profileRepo,
    friendRepo: FakeFriendRepository(friendUserIds: <UserId>{}),
    serverRepo: _serverRepo,
  );

  late final _voiceSessionsBloc = VoiceSessionsBloc(
    voiceSessionRepo: _voiceSessionRepo,
    voiceRuntimeService: _voiceRuntimeService,
    profileRepo: _profileRepo,
  );

  late final _notificationCenterBloc = NotificationCenterBloc(
    notificationRepo: _FakeNotificationRepository(
      totalUnreadCount: _totalUnreadCount,
    ),
    notificationRuntimeService: notificationRuntimeService,
    notificationService: FakeNotificationService(),
    notificationBadgeService: const NoOpNotificationBadgeService(),
    preferencesStore: preferencesStore,
  )..add(
      const NotificationCenterStartedRequested(bearerToken: "test-token"),
    );

  void registerTearDowns(void Function(dynamic Function()) addTearDown) {
    addTearDown(_authenticationBloc.close);
    addTearDown(serversBloc.close);
    addTearDown(channelsBloc.close);
    addTearDown(_messagesBloc.close);
    addTearDown(_profileBloc.close);
    addTearDown(serverMembersBloc.close);
    addTearDown(_voiceSessionsBloc.close);
    addTearDown(_notificationCenterBloc.close);
  }

  Widget buildWidget() {
    return MultiProvider(
      providers: [
        Provider<PreferencesStore>.value(value: preferencesStore),
        Provider<NotificationRuntimeService>(
          create: (_) => notificationRuntimeService,
        ),
        Provider<EmoteService>(
          create: (_) => FakeEmoteService(),
        ),
        Provider<LinkPreviewService>(
          create: (_) => FakeLinkPreviewService(),
        ),
        Provider<ReactionService>(
          create: (_) => FakeReactionService(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthenticationBloc>.value(value: _authenticationBloc),
          BlocProvider<ServersBloc>.value(value: serversBloc),
          BlocProvider<ChannelsBloc>.value(value: channelsBloc),
          BlocProvider<MessagesBloc>.value(value: _messagesBloc),
          BlocProvider<ProfileBloc>.value(value: _profileBloc),
          BlocProvider<ServerMembersBloc>.value(value: serverMembersBloc),
          BlocProvider<VoiceSessionsBloc>.value(value: _voiceSessionsBloc),
          BlocProvider<NotificationCenterBloc>.value(
            value: _notificationCenterBloc,
          ),
          BlocProvider<SettingsBloc>(
            create: (_) => SettingsBloc(
              preferencesStore: InMemoryPreferencesStore(),
              audioDeviceRuntimeService: FakeAudioDeviceRuntimeService(),
            )..add(const SettingsPreferencesRestoreRequested()),
          ),
        ],
        child: const MaterialApp(home: HomePageWidget()),
      ),
    );
  }
}

void main() {
  testWidgets(
    "loads server users when selected server changes",
    (tester) async {
      final harness = _HomePageTestHarness(totalUnreadCount: 3)
        ..registerTearDowns(addTearDown);

      await tester.pumpWidget(harness.buildWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      harness.serverMembersBloc.recordedEvents.clear();
      harness.serversBloc.add(
        SelectServerRequested(serverId: harness.fixture.listedServer.id),
      );
      await tester.pump();

      final loadEvents = harness.serverMembersBloc.recordedEvents
          .whereType<LoadServerMembersRequested>()
          .toList();

      expect(loadEvents, hasLength(1));
      expect(loadEvents.single.serverId, harness.fixture.listedServer.id);
    },
  );

  testWidgets(
    "renders without overflow on compact viewport",
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = _HomePageTestHarness()..registerTearDowns(addTearDown);

      await tester.pumpWidget(harness.buildWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.byType(HomePageWidget), findsOneWidget);
    },
  );

  testWidgets(
    "shows unread count badge when unread notifications exist",
    (tester) async {
      final harness = _HomePageTestHarness(totalUnreadCount: 7)
        ..registerTearDowns(addTearDown);

      await tester.pumpWidget(harness.buildWidget());
      await tester.pumpAndSettle();

      expect(find.text("7"), findsOneWidget);
    },
  );

  testWidgets(
    "friend joined voice event outside selected channels is not shown in notification feed",
    (tester) async {
      final preferencesStore = InMemoryPreferencesStore();
      await preferencesStore.writeChannelJoinNotificationsEnabled(true);
      await preferencesStore.writeChannelJoinNotificationChannelIds(
        const <String>["voice-allowed"],
      );

      final harness = _HomePageTestHarness(
        preferencesStore: preferencesStore,
      )..registerTearDowns(addTearDown);

      await tester.pumpWidget(harness.buildWidget());
      await tester.pumpAndSettle();

      harness.notificationRuntimeService.emit(
        const FriendJoinedVoiceRuntimeNotificationEvent(
          serverId: "server-1",
          serverName: "Server",
          channelId: "voice-blocked",
          channelName: "Blocked",
          joinedUserId: "user-2",
          joinedUserDisplayName: "Olivia",
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip("Notification feed"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text("No recent notifications."), findsOneWidget);
    },
  );

  testWidgets(
    "tapping notification feed entry selects its server and channel",
    (tester) async {
      final harness = _HomePageTestHarness()..registerTearDowns(addTearDown);

      await tester.pumpWidget(harness.buildWidget());
      await tester.pumpAndSettle();

      harness.notificationRuntimeService.emit(
        MentionedRuntimeNotificationEvent(
          serverId: harness.fixture.listedServer.id.value,
          serverName: harness.fixture.listedServer.name,
          channelId: harness.fixture.listedChannel.id.value,
          channelName: harness.fixture.listedChannel.name,
          messageId: harness.fixture.listedMessage.id.value,
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip("Notification feed"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text("You were mentioned"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final serversState = harness.serversBloc.state;
      expect(serversState, isA<ServerSelected>());
      expect((serversState as ServerSelected).selectedServer.id,
          harness.fixture.listedServer.id);

      final channelsState = harness.channelsBloc.state;
      expect(channelsState, isA<ChannelsLoadedDataState>());
      expect((channelsState as ChannelsLoadedDataState).serverId,
          harness.fixture.listedServer.id);
      expect(channelsState, isA<TextChannelSelected>());
      expect((channelsState as TextChannelSelected).selectedTextChannel.id,
          harness.fixture.listedChannel.id);
    },
  );

  testWidgets(
    "tapping stale notification entry shows unable-to-open channel toast",
    (tester) async {
      final harness = _HomePageTestHarness()..registerTearDowns(addTearDown);

      await tester.pumpWidget(harness.buildWidget());
      await tester.pumpAndSettle();

      harness.notificationRuntimeService.emit(
        MentionedRuntimeNotificationEvent(
          serverId: harness.fixture.listedServer.id.value,
          serverName: harness.fixture.listedServer.name,
          channelId: "missing-channel-id",
          channelName: "missing",
          messageId: harness.fixture.listedMessage.id.value,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byTooltip("Notification feed"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text("You were mentioned"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text("Unable to open notification channel."), findsOneWidget);

      // Flush the error toast auto-dismiss timer to avoid pending timers at test end.
      await tester.pump(const Duration(seconds: 5));
    },
  );
}
