import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/notifications/bloc/notification_center_bloc.dart";
import "package:polyphony_flutter_client/shared/repositories/notification_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/notification_runtime_service.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";

import "../test_doubles/chat_repository_fakes.dart";

class _FakeNotificationRepository implements NotificationRepo {
  _FakeNotificationRepository({
    required this.totalUnreadCount,
  });

  final int totalUnreadCount;

  @override
  Future<Result<int>> getOne({
    required GetNotificationUnreadCountQuery query,
  }) async {
    return Ok<int>(totalUnreadCount);
  }
}

void main() {
  late FakeNotificationRuntimeService runtimeService;
  late InMemoryPreferencesStore preferencesStore;

  setUp(() {
    runtimeService = FakeNotificationRuntimeService();
    preferencesStore = InMemoryPreferencesStore();
  });

  blocTest<NotificationCenterBloc, NotificationCenterState>(
    "loads unread count when started",
    build: () {
      return NotificationCenterBloc(
        notificationRepo: _FakeNotificationRepository(totalUnreadCount: 5),
        notificationRuntimeService: runtimeService,
      );
    },
    act: (bloc) => bloc.add(
      const NotificationCenterStartedRequested(
        backendBaseUrl: "http://localhost:3000",
        bearerToken: "token",
      ),
    ),
    expect: () => <Matcher>[
      isA<NotificationCenterLoadedState>().having(
        (state) => state.totalUnreadCount,
        "total unread count",
        5,
      ),
    ],
  );

  blocTest<NotificationCenterBloc, NotificationCenterState>(
    "adds runtime notifications to feed",
    build: () {
      return NotificationCenterBloc(
        notificationRepo: _FakeNotificationRepository(totalUnreadCount: 2),
        notificationRuntimeService: runtimeService,
      );
    },
    act: (bloc) async {
      bloc.add(
        const NotificationCenterStartedRequested(
          backendBaseUrl: "http://localhost:3000",
          bearerToken: "token",
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 1));

      runtimeService.emit(
        const MentionedRuntimeNotificationEvent(
          serverId: "server-1",
          serverName: "Server",
          channelId: "channel-1",
          channelName: "general",
          messageId: "message-1",
        ),
      );
    },
    wait: const Duration(milliseconds: 20),
    expect: () => <Matcher>[
      isA<NotificationCenterLoadedState>(),
      isA<NotificationCenterLoadedState>().having(
        (state) => state.entries.length,
        "entries length",
        1,
      ),
      isA<NotificationCenterLoadedState>().having(
        (state) => state.entries.length,
        "entries length",
        1,
      ),
    ],
  );

  blocTest<NotificationCenterBloc, NotificationCenterState>(
    "ignores friend joined voice notifications when disabled by default",
    build: () {
      return NotificationCenterBloc(
        notificationRepo: _FakeNotificationRepository(totalUnreadCount: 2),
        notificationRuntimeService: runtimeService,
        preferencesStore: preferencesStore,
      );
    },
    act: (bloc) async {
      bloc.add(
        const NotificationCenterStartedRequested(
          backendBaseUrl: "http://localhost:3000",
          bearerToken: "token",
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 1));

      runtimeService.emit(
        const FriendJoinedVoiceRuntimeNotificationEvent(
          serverId: "server-1",
          serverName: "Server",
          channelId: "voice-1",
          channelName: "Lobby",
          joinedUserId: "user-2",
          joinedUserDisplayName: "Olivia",
        ),
      );
    },
    wait: const Duration(milliseconds: 20),
    expect: () => <Matcher>[
      isA<NotificationCenterLoadedState>().having(
        (state) => state.entries.length,
        "entries length",
        0,
      ),
    ],
  );

  blocTest<NotificationCenterBloc, NotificationCenterState>(
    "adds friend joined voice notifications when enabled",
    build: () {
      return NotificationCenterBloc(
        notificationRepo: _FakeNotificationRepository(totalUnreadCount: 2),
        notificationRuntimeService: runtimeService,
        preferencesStore: preferencesStore,
      );
    },
    act: (bloc) async {
      await preferencesStore.writeChannelJoinNotificationsEnabled(true);

      bloc.add(
        const NotificationCenterStartedRequested(
          backendBaseUrl: "http://localhost:3000",
          bearerToken: "token",
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 1));

      runtimeService.emit(
        const FriendJoinedVoiceRuntimeNotificationEvent(
          serverId: "server-1",
          serverName: "Server",
          channelId: "voice-1",
          channelName: "Lobby",
          joinedUserId: "user-2",
          joinedUserDisplayName: "Olivia",
        ),
      );
    },
    wait: const Duration(milliseconds: 20),
    expect: () => <Matcher>[
      isA<NotificationCenterLoadedState>(),
      isA<NotificationCenterLoadedState>().having(
        (state) => state.entries.length,
        "entries length",
        1,
      ),
      isA<NotificationCenterLoadedState>().having(
        (state) => state.entries.length,
        "entries length",
        1,
      ),
    ],
  );
}
