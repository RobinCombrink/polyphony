import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
import "package:polyphony_flutter_client/features/channels/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/home/presentation/home_page_widget.dart";
import "package:polyphony_flutter_client/features/identity/bloc/profile_bloc.dart";
import "package:polyphony_flutter_client/features/messages/bloc/messages_bloc.dart";
import "package:polyphony_flutter_client/features/notifications/bloc/notification_unread_count_bloc.dart";
import "package:polyphony_flutter_client/features/servers/bloc/server_members_bloc.dart";
import "package:polyphony_flutter_client/features/servers/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/features/voice_sessions/bloc/voice_sessions_bloc.dart";
import "package:polyphony_flutter_client/shared/auth/access_token_provider.dart";
import "package:polyphony_flutter_client/shared/auth/authentication_profile_service.dart";
import "package:polyphony_flutter_client/shared/auth/authentication_session_service.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/repositories/notification_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/notification_runtime_service.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";
import "package:provider/provider.dart";

import "../entity_seeder.dart";
import "../test_doubles/chat_repository_fakes.dart";

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

class _FakeAuthenticationProfileService extends AuthenticationProfileService {
  _FakeAuthenticationProfileService({required this.userId})
      : super(httpClient: http.Client());

  final String userId;

  @override
  Future<Result<ApiMe>> getMe({required String bearerToken}) async {
    return Ok<ApiMe>(
      ApiMe(
        userId: userId,
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

  @override
  Future<Result<ApiNotificationGlobalPreference>>
      getGlobalNotificationPreference() async {
    return const Ok<ApiNotificationGlobalPreference>(
      ApiNotificationGlobalPreference(
        muteState: ApiNotificationMuteState.unmuted,
        notificationCategory: ApiNotificationCategoryPreference.onlyMentions,
        channelDefaultCategory: ApiNotificationCategoryPreference.onlyMentions,
      ),
    );
  }

  @override
  Future<Result<void>> updateGlobalNotificationPreference({
    ApiNotificationMuteState? muteState,
    ApiNotificationCategoryPreference? notificationCategory,
    ApiNotificationCategoryPreference? channelDefaultCategory,
  }) async {
    return const Ok<void>(null);
  }

  @override
  Future<Result<ApiNotificationServerPreference>>
      getServerNotificationPreference({
    required String serverId,
  }) async {
    return const Ok<ApiNotificationServerPreference>(
      ApiNotificationServerPreference(
        muteState: ApiNotificationMuteState.unmuted,
        notificationCategory: ApiNotificationCategoryPreference.onlyMentions,
      ),
    );
  }

  @override
  Future<Result<void>> updateServerNotificationPreference({
    required String serverId,
    ApiNotificationMuteState? muteState,
    ApiNotificationCategoryPreference? notificationCategory,
  }) async {
    return const Ok<void>(null);
  }

  @override
  Future<Result<ApiNotificationChannelPreference>>
      getChannelNotificationPreference({
    required String channelId,
  }) async {
    return const Ok<ApiNotificationChannelPreference>(
      ApiNotificationChannelPreference(
        muteState: ApiNotificationMuteState.unmuted,
        mutedUntilEpochSeconds: null,
        notificationCategory: ApiNotificationCategoryPreference.onlyMentions,
        inheritedFromGlobalDefault: true,
      ),
    );
  }

  @override
  Future<Result<void>> updateChannelNotificationPreference({
    required String channelId,
    required ApiNotificationCategoryPreference notificationCategory,
  }) async {
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> muteChannelNotifications({
    required String channelId,
    required int durationMinutes,
  }) async {
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> unmuteChannelNotifications({
    required String channelId,
  }) async {
    return const Ok<void>(null);
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
      final notificationUnreadCountBloc = NotificationUnreadCountBloc(
        notificationRepo: _FakeNotificationRepository(totalUnreadCount: 3),
      )..add(const LoadNotificationUnreadCountRequested());

      addTearDown(authenticationBloc.close);
      addTearDown(serversBloc.close);
      addTearDown(channelsBloc.close);
      addTearDown(messagesBloc.close);
      addTearDown(profileBloc.close);
      addTearDown(serverMembersBloc.close);
      addTearDown(voiceSessionsBloc.close);
      addTearDown(notificationUnreadCountBloc.close);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<PreferencesStore>(
              create: (_) => InMemoryPreferencesStore(),
            ),
            Provider<NotificationRuntimeService>(
              create: (_) => notificationRuntimeService,
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
              BlocProvider<NotificationUnreadCountBloc>.value(
                value: notificationUnreadCountBloc,
              ),
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

  testWidgets(
    "renders without overflow on compact viewport",
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fixture = EntitySeeder().chatApiFixture();
      final serverRepo = FakeServerRepository(fixture: fixture);
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
      final notificationUnreadCountBloc = NotificationUnreadCountBloc(
        notificationRepo: _FakeNotificationRepository(),
      )..add(const LoadNotificationUnreadCountRequested());

      addTearDown(authenticationBloc.close);
      addTearDown(serversBloc.close);
      addTearDown(channelsBloc.close);
      addTearDown(messagesBloc.close);
      addTearDown(profileBloc.close);
      addTearDown(serverMembersBloc.close);
      addTearDown(voiceSessionsBloc.close);
      addTearDown(notificationUnreadCountBloc.close);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<PreferencesStore>(
              create: (_) => InMemoryPreferencesStore(),
            ),
            Provider<NotificationRuntimeService>(
              create: (_) => notificationRuntimeService,
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
              BlocProvider<NotificationUnreadCountBloc>.value(
                value: notificationUnreadCountBloc,
              ),
            ],
            child: const MaterialApp(home: HomePageWidget()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(HomePageWidget), findsOneWidget);
    },
  );

  testWidgets(
    "shows unread count badge when unread notifications exist",
    (tester) async {
      final fixture = EntitySeeder().chatApiFixture();
      final serverRepo = FakeServerRepository(fixture: fixture);
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
      final notificationUnreadCountBloc = NotificationUnreadCountBloc(
        notificationRepo: _FakeNotificationRepository(totalUnreadCount: 7),
      )..add(const LoadNotificationUnreadCountRequested());

      addTearDown(authenticationBloc.close);
      addTearDown(serversBloc.close);
      addTearDown(channelsBloc.close);
      addTearDown(messagesBloc.close);
      addTearDown(profileBloc.close);
      addTearDown(serverMembersBloc.close);
      addTearDown(voiceSessionsBloc.close);
      addTearDown(notificationUnreadCountBloc.close);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<PreferencesStore>(
              create: (_) => InMemoryPreferencesStore(),
            ),
            Provider<NotificationRuntimeService>(
              create: (_) => notificationRuntimeService,
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
              BlocProvider<NotificationUnreadCountBloc>.value(
                value: notificationUnreadCountBloc,
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
}
