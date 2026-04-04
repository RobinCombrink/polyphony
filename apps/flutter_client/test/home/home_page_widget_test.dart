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
import "package:polyphony_flutter_client/shared/services/notification_service.dart";
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

class _FakeNotificationService implements NotificationService {
  @override
  Future<Result<ApiNotificationUnreadCount>>
      getUnreadNotificationCount() async {
    return const Ok<ApiNotificationUnreadCount>(
      ApiNotificationUnreadCount(totalUnreadCount: 0),
    );
  }

  @override
  Future<Result<ApiNotificationGlobalPreference>>
      getGlobalNotificationPreference() async {
    return Error<ApiNotificationGlobalPreference>(
      Exception("Not used in test."),
    );
  }

  @override
  Future<Result<ApiNotificationServerPreference>>
      getServerNotificationPreference({
    required String serverId,
  }) async {
    return Error<ApiNotificationServerPreference>(
      Exception("Not used in test."),
    );
  }

  @override
  Future<Result<ApiNotificationChannelPreference>>
      getChannelNotificationPreference({
    required String channelId,
  }) async {
    return Error<ApiNotificationChannelPreference>(
      Exception("Not used in test."),
    );
  }

  @override
  Future<Result<void>> markChannelNotificationsRead({
    required String channelId,
  }) async {
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> muteChannelNotifications({
    required String channelId,
    required int durationMinutes,
  }) async {
    return Error<void>(Exception("Not used in test."));
  }

  @override
  Future<Result<void>> unmuteChannelNotifications({
    required String channelId,
  }) async {
    return Error<void>(Exception("Not used in test."));
  }

  @override
  Future<Result<void>> updateChannelNotificationPreference({
    required String channelId,
    required ApiNotificationCategoryPreference notificationCategory,
  }) async {
    return Error<void>(Exception("Not used in test."));
  }

  @override
  Future<Result<void>> updateGlobalNotificationPreference({
    ApiNotificationMuteState? muteState,
    ApiNotificationCategoryPreference? notificationCategory,
    ApiNotificationCategoryPreference? channelDefaultCategory,
  }) async {
    return Error<void>(Exception("Not used in test."));
  }

  @override
  Future<Result<void>> updateServerNotificationPreference({
    required String serverId,
    ApiNotificationMuteState? muteState,
    ApiNotificationCategoryPreference? notificationCategory,
  }) async {
    return Error<void>(Exception("Not used in test."));
  }
}

void main() {
  testWidgets(
    "loads server users when selected server changes",
    (tester) async {
      final fixture = EntitySeeder().chatApiFixture();
      final serverRepo = FakeServerRepository(fixture: fixture);
      final serverMemberRepo = FakeServerMemberRepository(fixture: fixture);
      final channelRepo = FakeChannelRepository(fixture: fixture);
      final messageRepo = FakeMessageRepository(fixture: fixture);
      final profileRepo = FakeProfileRepository(
        userId: fixture.ownerUserId,
        initialDisplayName: "Owner",
      );
      final textSessionRepo = FakeTextSessionRepository(fixture: fixture);
      final voiceSessionRepo = FakeVoiceSessionRepository(fixture: fixture);
      final voiceRuntimeService = FakeVoiceRuntimeService();
      final messageRuntimeService = FakeMessageRuntimeService();
      final notificationRuntimeService = FakeNotificationRuntimeService();

      final authenticationBloc = AuthenticationBloc(
        profileService: _FakeAuthenticationProfileService(
          userId: fixture.ownerUserId,
        ),
        sessionService: _FakeAuthenticationSessionService(),
      )..add(const AuthenticationLoginRequested(bearerToken: "test-token"));
      final serversBloc = ServersBloc(serverRepo: serverRepo);
      final channelsBloc = ChannelsBloc(channelRepo: channelRepo);
      final messagesBloc = MessagesBloc(
        messageRepo: messageRepo,
        profileRepo: profileRepo,
        textSessionRepo: textSessionRepo,
        messageRuntimeService: messageRuntimeService,
      );
      final profileBloc = ProfileBloc(
          profileRepo: profileRepo, currentUserId: fixture.ownerUserId);
      final serverMembersBloc = _RecordingServerMembersBloc(
        serverMemberRepo: serverMemberRepo,
        profileRepo: profileRepo,
        friendRepo: FakeFriendRepository(friendUserIds: <UserId>{}),
        serverRepo: serverRepo,
      );
      final voiceSessionsBloc = VoiceSessionsBloc(
        voiceSessionRepo: voiceSessionRepo,
        voiceRuntimeService: voiceRuntimeService,
        profileRepo: profileRepo,
      );
      final notificationCenterBloc = NotificationCenterBloc(
        notificationRepo: _FakeNotificationRepository(totalUnreadCount: 3),
        notificationRuntimeService: notificationRuntimeService,
        notificationBadgeService: const NoOpNotificationBadgeService(),
        preferencesStore: InMemoryPreferencesStore(),
      )..add(
          const NotificationCenterStartedRequested(
            bearerToken: "test-token",
          ),
        );

      addTearDown(authenticationBloc.close);
      addTearDown(serversBloc.close);
      addTearDown(channelsBloc.close);
      addTearDown(messagesBloc.close);
      addTearDown(profileBloc.close);
      addTearDown(serverMembersBloc.close);
      addTearDown(voiceSessionsBloc.close);
      addTearDown(notificationCenterBloc.close);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<PreferencesStore>(
              create: (_) => InMemoryPreferencesStore(),
            ),
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
              BlocProvider<AuthenticationBloc>.value(value: authenticationBloc),
              BlocProvider<ServersBloc>.value(value: serversBloc),
              BlocProvider<ChannelsBloc>.value(value: channelsBloc),
              BlocProvider<MessagesBloc>.value(value: messagesBloc),
              BlocProvider<ProfileBloc>.value(value: profileBloc),
              BlocProvider<ServerMembersBloc>.value(value: serverMembersBloc),
              BlocProvider<VoiceSessionsBloc>.value(value: voiceSessionsBloc),
              BlocProvider<NotificationCenterBloc>.value(
                value: notificationCenterBloc,
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
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

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

  testWidgets(
    "renders without overflow on compact viewport",
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fixture = EntitySeeder().chatApiFixture();
      final serverRepo = FakeServerRepository(fixture: fixture);
      final serverMemberRepo = FakeServerMemberRepository(fixture: fixture);
      final channelRepo = FakeChannelRepository(fixture: fixture);
      final messageRepo = FakeMessageRepository(fixture: fixture);
      final profileRepo = FakeProfileRepository(
        userId: fixture.ownerUserId,
        initialDisplayName: "Owner",
      );
      final textSessionRepo = FakeTextSessionRepository(fixture: fixture);
      final voiceSessionRepo = FakeVoiceSessionRepository(fixture: fixture);
      final voiceRuntimeService = FakeVoiceRuntimeService();
      final messageRuntimeService = FakeMessageRuntimeService();
      final notificationRuntimeService = FakeNotificationRuntimeService();

      final authenticationBloc = AuthenticationBloc(
        profileService: _FakeAuthenticationProfileService(
          userId: fixture.ownerUserId,
        ),
        sessionService: _FakeAuthenticationSessionService(),
      )..add(const AuthenticationLoginRequested(bearerToken: "test-token"));
      final serversBloc = ServersBloc(serverRepo: serverRepo);
      final channelsBloc = ChannelsBloc(channelRepo: channelRepo);
      final messagesBloc = MessagesBloc(
        messageRepo: messageRepo,
        profileRepo: profileRepo,
        textSessionRepo: textSessionRepo,
        messageRuntimeService: messageRuntimeService,
      );
      final profileBloc = ProfileBloc(
          profileRepo: profileRepo, currentUserId: fixture.ownerUserId);
      final serverMembersBloc = _RecordingServerMembersBloc(
        serverMemberRepo: serverMemberRepo,
        profileRepo: profileRepo,
        friendRepo: FakeFriendRepository(friendUserIds: <UserId>{}),
        serverRepo: serverRepo,
      );
      final voiceSessionsBloc = VoiceSessionsBloc(
        voiceSessionRepo: voiceSessionRepo,
        voiceRuntimeService: voiceRuntimeService,
        profileRepo: profileRepo,
      );
      final notificationCenterBloc = NotificationCenterBloc(
        notificationRepo: _FakeNotificationRepository(),
        notificationRuntimeService: notificationRuntimeService,
        notificationBadgeService: const NoOpNotificationBadgeService(),
        preferencesStore: InMemoryPreferencesStore(),
      )..add(
          const NotificationCenterStartedRequested(
            bearerToken: "test-token",
          ),
        );

      addTearDown(authenticationBloc.close);
      addTearDown(serversBloc.close);
      addTearDown(channelsBloc.close);
      addTearDown(messagesBloc.close);
      addTearDown(profileBloc.close);
      addTearDown(serverMembersBloc.close);
      addTearDown(voiceSessionsBloc.close);
      addTearDown(notificationCenterBloc.close);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<PreferencesStore>(
              create: (_) => InMemoryPreferencesStore(),
            ),
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
              BlocProvider<AuthenticationBloc>.value(value: authenticationBloc),
              BlocProvider<ServersBloc>.value(value: serversBloc),
              BlocProvider<ChannelsBloc>.value(value: channelsBloc),
              BlocProvider<MessagesBloc>.value(value: messagesBloc),
              BlocProvider<ProfileBloc>.value(value: profileBloc),
              BlocProvider<ServerMembersBloc>.value(value: serverMembersBloc),
              BlocProvider<VoiceSessionsBloc>.value(value: voiceSessionsBloc),
              BlocProvider<NotificationCenterBloc>.value(
                value: notificationCenterBloc,
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
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.byType(HomePageWidget), findsOneWidget);
    },
  );

  testWidgets(
    "shows unread count badge when unread notifications exist",
    (tester) async {
      final fixture = EntitySeeder().chatApiFixture();
      final serverRepo = FakeServerRepository(fixture: fixture);
      final serverMemberRepo = FakeServerMemberRepository(fixture: fixture);
      final channelRepo = FakeChannelRepository(fixture: fixture);
      final messageRepo = FakeMessageRepository(fixture: fixture);
      final profileRepo = FakeProfileRepository(
        userId: fixture.ownerUserId,
        initialDisplayName: "Owner",
      );
      final textSessionRepo = FakeTextSessionRepository(fixture: fixture);
      final voiceSessionRepo = FakeVoiceSessionRepository(fixture: fixture);
      final voiceRuntimeService = FakeVoiceRuntimeService();
      final messageRuntimeService = FakeMessageRuntimeService();
      final notificationRuntimeService = FakeNotificationRuntimeService();

      final authenticationBloc = AuthenticationBloc(
        profileService: _FakeAuthenticationProfileService(
          userId: fixture.ownerUserId,
        ),
        sessionService: _FakeAuthenticationSessionService(),
      )..add(const AuthenticationLoginRequested(bearerToken: "test-token"));
      final serversBloc = ServersBloc(serverRepo: serverRepo);
      final channelsBloc = ChannelsBloc(channelRepo: channelRepo);
      final messagesBloc = MessagesBloc(
        messageRepo: messageRepo,
        profileRepo: profileRepo,
        textSessionRepo: textSessionRepo,
        messageRuntimeService: messageRuntimeService,
      );
      final profileBloc = ProfileBloc(
          profileRepo: profileRepo, currentUserId: fixture.ownerUserId);
      final serverMembersBloc = _RecordingServerMembersBloc(
        serverMemberRepo: serverMemberRepo,
        profileRepo: profileRepo,
        friendRepo: FakeFriendRepository(friendUserIds: <UserId>{}),
        serverRepo: serverRepo,
      );
      final voiceSessionsBloc = VoiceSessionsBloc(
        voiceSessionRepo: voiceSessionRepo,
        voiceRuntimeService: voiceRuntimeService,
        profileRepo: profileRepo,
      );
      final notificationCenterBloc = NotificationCenterBloc(
        notificationRepo: _FakeNotificationRepository(totalUnreadCount: 7),
        notificationRuntimeService: notificationRuntimeService,
        notificationBadgeService: const NoOpNotificationBadgeService(),
        preferencesStore: InMemoryPreferencesStore(),
      )..add(
          const NotificationCenterStartedRequested(
            bearerToken: "test-token",
          ),
        );

      addTearDown(authenticationBloc.close);
      addTearDown(serversBloc.close);
      addTearDown(channelsBloc.close);
      addTearDown(messagesBloc.close);
      addTearDown(profileBloc.close);
      addTearDown(serverMembersBloc.close);
      addTearDown(voiceSessionsBloc.close);
      addTearDown(notificationCenterBloc.close);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<PreferencesStore>(
              create: (_) => InMemoryPreferencesStore(),
            ),
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
              BlocProvider<AuthenticationBloc>.value(value: authenticationBloc),
              BlocProvider<ServersBloc>.value(value: serversBloc),
              BlocProvider<ChannelsBloc>.value(value: channelsBloc),
              BlocProvider<MessagesBloc>.value(value: messagesBloc),
              BlocProvider<ProfileBloc>.value(value: profileBloc),
              BlocProvider<ServerMembersBloc>.value(value: serverMembersBloc),
              BlocProvider<VoiceSessionsBloc>.value(value: voiceSessionsBloc),
              BlocProvider<NotificationCenterBloc>.value(
                value: notificationCenterBloc,
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
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("7"), findsOneWidget);
    },
  );

  testWidgets(
    "friend joined voice event outside selected channels is not shown in notification feed",
    (tester) async {
      final fixture = EntitySeeder().chatApiFixture();
      final serverRepo = FakeServerRepository(fixture: fixture);
      final serverMemberRepo = FakeServerMemberRepository(fixture: fixture);
      final channelRepo = FakeChannelRepository(fixture: fixture);
      final messageRepo = FakeMessageRepository(fixture: fixture);
      final profileRepo = FakeProfileRepository(
        userId: fixture.ownerUserId,
        initialDisplayName: "Owner",
      );
      final textSessionRepo = FakeTextSessionRepository(fixture: fixture);
      final voiceSessionRepo = FakeVoiceSessionRepository(fixture: fixture);
      final voiceRuntimeService = FakeVoiceRuntimeService();
      final messageRuntimeService = FakeMessageRuntimeService();
      final notificationRuntimeService = FakeNotificationRuntimeService();
      final preferencesStore = InMemoryPreferencesStore();

      await preferencesStore.writeChannelJoinNotificationsEnabled(true);
      await preferencesStore.writeChannelJoinNotificationChannelIds(
        const <String>["voice-allowed"],
      );

      final authenticationBloc = AuthenticationBloc(
        profileService: _FakeAuthenticationProfileService(
          userId: fixture.ownerUserId,
        ),
        sessionService: _FakeAuthenticationSessionService(),
      )..add(const AuthenticationLoginRequested(bearerToken: "test-token"));
      final serversBloc = ServersBloc(serverRepo: serverRepo);
      final channelsBloc = ChannelsBloc(channelRepo: channelRepo);
      final messagesBloc = MessagesBloc(
        messageRepo: messageRepo,
        profileRepo: profileRepo,
        textSessionRepo: textSessionRepo,
        messageRuntimeService: messageRuntimeService,
      );
      final profileBloc = ProfileBloc(
          profileRepo: profileRepo, currentUserId: fixture.ownerUserId);
      final serverMembersBloc = _RecordingServerMembersBloc(
        serverMemberRepo: serverMemberRepo,
        profileRepo: profileRepo,
        friendRepo: FakeFriendRepository(friendUserIds: <UserId>{}),
        serverRepo: serverRepo,
      );
      final voiceSessionsBloc = VoiceSessionsBloc(
        voiceSessionRepo: voiceSessionRepo,
        voiceRuntimeService: voiceRuntimeService,
        profileRepo: profileRepo,
      );
      final notificationCenterBloc = NotificationCenterBloc(
        notificationRepo: _FakeNotificationRepository(),
        notificationRuntimeService: notificationRuntimeService,
        notificationBadgeService: const NoOpNotificationBadgeService(),
        preferencesStore: preferencesStore,
      )..add(
          const NotificationCenterStartedRequested(
            bearerToken: "test-token",
          ),
        );

      addTearDown(authenticationBloc.close);
      addTearDown(serversBloc.close);
      addTearDown(channelsBloc.close);
      addTearDown(messagesBloc.close);
      addTearDown(profileBloc.close);
      addTearDown(serverMembersBloc.close);
      addTearDown(voiceSessionsBloc.close);
      addTearDown(notificationCenterBloc.close);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<PreferencesStore>.value(
              value: preferencesStore,
            ),
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
            Provider<NotificationService>(
              create: (_) => _FakeNotificationService(),
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
              BlocProvider<NotificationCenterBloc>.value(
                value: notificationCenterBloc,
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
        ),
      );

      await tester.pumpAndSettle();

      notificationRuntimeService.emit(
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
      final fixture = EntitySeeder().chatApiFixture();
      final serverRepo = FakeServerRepository(fixture: fixture);
      final serverMemberRepo = FakeServerMemberRepository(fixture: fixture);
      final channelRepo = FakeChannelRepository(fixture: fixture);
      final messageRepo = FakeMessageRepository(fixture: fixture);
      final profileRepo = FakeProfileRepository(
        userId: fixture.ownerUserId,
        initialDisplayName: "Owner",
      );
      final textSessionRepo = FakeTextSessionRepository(fixture: fixture);
      final voiceSessionRepo = FakeVoiceSessionRepository(fixture: fixture);
      final voiceRuntimeService = FakeVoiceRuntimeService();
      final messageRuntimeService = FakeMessageRuntimeService();
      final notificationRuntimeService = FakeNotificationRuntimeService();

      final authenticationBloc = AuthenticationBloc(
        profileService: _FakeAuthenticationProfileService(
          userId: fixture.ownerUserId,
        ),
        sessionService: _FakeAuthenticationSessionService(),
      )..add(const AuthenticationLoginRequested(bearerToken: "test-token"));
      final serversBloc = ServersBloc(serverRepo: serverRepo);
      final channelsBloc = ChannelsBloc(channelRepo: channelRepo);
      final messagesBloc = MessagesBloc(
        messageRepo: messageRepo,
        profileRepo: profileRepo,
        textSessionRepo: textSessionRepo,
        messageRuntimeService: messageRuntimeService,
      );
      final profileBloc = ProfileBloc(
          profileRepo: profileRepo, currentUserId: fixture.ownerUserId);
      final serverMembersBloc = _RecordingServerMembersBloc(
        serverMemberRepo: serverMemberRepo,
        profileRepo: profileRepo,
        friendRepo: FakeFriendRepository(friendUserIds: <UserId>{}),
        serverRepo: serverRepo,
      );
      final voiceSessionsBloc = VoiceSessionsBloc(
        voiceSessionRepo: voiceSessionRepo,
        voiceRuntimeService: voiceRuntimeService,
        profileRepo: profileRepo,
      );
      final notificationCenterBloc = NotificationCenterBloc(
        notificationRepo: _FakeNotificationRepository(),
        notificationRuntimeService: notificationRuntimeService,
        notificationBadgeService: const NoOpNotificationBadgeService(),
        preferencesStore: InMemoryPreferencesStore(),
      )..add(
          const NotificationCenterStartedRequested(
            bearerToken: "test-token",
          ),
        );

      addTearDown(authenticationBloc.close);
      addTearDown(serversBloc.close);
      addTearDown(channelsBloc.close);
      addTearDown(messagesBloc.close);
      addTearDown(profileBloc.close);
      addTearDown(serverMembersBloc.close);
      addTearDown(voiceSessionsBloc.close);
      addTearDown(notificationCenterBloc.close);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<PreferencesStore>(
              create: (_) => InMemoryPreferencesStore(),
            ),
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
            Provider<NotificationService>(
              create: (_) => _FakeNotificationService(),
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
              BlocProvider<NotificationCenterBloc>.value(
                value: notificationCenterBloc,
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
        ),
      );

      await tester.pumpAndSettle();

      notificationRuntimeService.emit(
        MentionedRuntimeNotificationEvent(
          serverId: fixture.listedServer.id.value,
          serverName: fixture.listedServer.name,
          channelId: fixture.listedChannel.id.value,
          channelName: fixture.listedChannel.name,
          messageId: fixture.listedMessage.id.value,
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip("Notification feed"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text("You were mentioned"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final serversState = serversBloc.state;
      expect(serversState, isA<ServerSelected>());
      expect((serversState as ServerSelected).selectedServer.id,
          fixture.listedServer.id);

      final channelsState = channelsBloc.state;
      expect(channelsState, isA<ChannelsLoadedDataState>());
      expect((channelsState as ChannelsLoadedDataState).serverId,
          fixture.listedServer.id);
      expect(channelsState, isA<TextChannelSelected>());
      expect((channelsState as TextChannelSelected).selectedTextChannel.id,
          fixture.listedChannel.id);
    },
  );

  testWidgets(
    "tapping stale notification entry shows unable-to-open channel toast",
    (tester) async {
      final fixture = EntitySeeder().chatApiFixture();
      final serverRepo = FakeServerRepository(fixture: fixture);
      final serverMemberRepo = FakeServerMemberRepository(fixture: fixture);
      final channelRepo = FakeChannelRepository(fixture: fixture);
      final messageRepo = FakeMessageRepository(fixture: fixture);
      final profileRepo = FakeProfileRepository(
        userId: fixture.ownerUserId,
        initialDisplayName: "Owner",
      );
      final textSessionRepo = FakeTextSessionRepository(fixture: fixture);
      final voiceSessionRepo = FakeVoiceSessionRepository(fixture: fixture);
      final voiceRuntimeService = FakeVoiceRuntimeService();
      final messageRuntimeService = FakeMessageRuntimeService();
      final notificationRuntimeService = FakeNotificationRuntimeService();

      final authenticationBloc = AuthenticationBloc(
        profileService: _FakeAuthenticationProfileService(
          userId: fixture.ownerUserId,
        ),
        sessionService: _FakeAuthenticationSessionService(),
      )..add(const AuthenticationLoginRequested(bearerToken: "test-token"));
      final serversBloc = ServersBloc(serverRepo: serverRepo);
      final channelsBloc = ChannelsBloc(channelRepo: channelRepo);
      final messagesBloc = MessagesBloc(
        messageRepo: messageRepo,
        profileRepo: profileRepo,
        textSessionRepo: textSessionRepo,
        messageRuntimeService: messageRuntimeService,
      );
      final profileBloc = ProfileBloc(
          profileRepo: profileRepo, currentUserId: fixture.ownerUserId);
      final serverMembersBloc = _RecordingServerMembersBloc(
        serverMemberRepo: serverMemberRepo,
        profileRepo: profileRepo,
        friendRepo: FakeFriendRepository(friendUserIds: <UserId>{}),
        serverRepo: serverRepo,
      );
      final voiceSessionsBloc = VoiceSessionsBloc(
        voiceSessionRepo: voiceSessionRepo,
        voiceRuntimeService: voiceRuntimeService,
        profileRepo: profileRepo,
      );
      final notificationCenterBloc = NotificationCenterBloc(
        notificationRepo: _FakeNotificationRepository(),
        notificationRuntimeService: notificationRuntimeService,
        notificationBadgeService: const NoOpNotificationBadgeService(),
        preferencesStore: InMemoryPreferencesStore(),
      )..add(
          const NotificationCenterStartedRequested(
            bearerToken: "test-token",
          ),
        );

      addTearDown(authenticationBloc.close);
      addTearDown(serversBloc.close);
      addTearDown(channelsBloc.close);
      addTearDown(messagesBloc.close);
      addTearDown(profileBloc.close);
      addTearDown(serverMembersBloc.close);
      addTearDown(voiceSessionsBloc.close);
      addTearDown(notificationCenterBloc.close);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<PreferencesStore>(
              create: (_) => InMemoryPreferencesStore(),
            ),
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
            Provider<NotificationService>(
              create: (_) => _FakeNotificationService(),
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
              BlocProvider<NotificationCenterBloc>.value(
                value: notificationCenterBloc,
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
        ),
      );

      await tester.pumpAndSettle();

      notificationRuntimeService.emit(
        MentionedRuntimeNotificationEvent(
          serverId: fixture.listedServer.id.value,
          serverName: fixture.listedServer.name,
          channelId: "missing-channel-id",
          channelName: "missing",
          messageId: fixture.listedMessage.id.value,
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
