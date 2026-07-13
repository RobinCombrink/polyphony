import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/notifications/bloc/notification_center_bloc.dart";
import "package:polyphony_flutter_client/shared/repositories/notification_repo.dart";
import "package:polyphony_flutter_client/shared/services/notification_badge_service.dart";
import "package:polyphony_flutter_client/shared/services/notification_runtime_service.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";

import "../test_doubles/chat_repository_fakes.dart";

class _FakeNotificationBadgeService implements NotificationBadgeService {
  final syncedUnreadCounts = <int>[];

  @override
  Future<void> syncUnreadCount({required int totalUnreadCount}) async {
    syncedUnreadCounts.add(totalUnreadCount);
  }
}

NotificationCenterBloc _buildBloc({
  required NotificationRepo notificationRepo,
  required FakeNotificationRuntimeService runtimeService,
  required NotificationBadgeService notificationBadgeService,
  required PreferencesStore preferencesStore,
}) {
  return NotificationCenterBloc(
    notificationRepo: notificationRepo,
    notificationRuntimeService: runtimeService,
    notificationBadgeService: notificationBadgeService,
    preferencesStore: preferencesStore,
  );
}

void main() {
  group("Feature: Notifications", () {
    group(
      "Rule: Friend-joined-voice feed filtering follows selected channels",
      () {
        late FakeNotificationRuntimeService runtimeService;
        late InMemoryPreferencesStore preferencesStore;
        late _FakeNotificationBadgeService notificationBadgeService;

        setUp(() {
          runtimeService = FakeNotificationRuntimeService();
          preferencesStore = InMemoryPreferencesStore();
          notificationBadgeService = _FakeNotificationBadgeService();
        });

        blocTest<NotificationCenterBloc, NotificationCenterState>(
          "Scenario: Mentioned event is shown in feed",
          build: () {
            return _buildBloc(
              notificationRepo: FakeNotificationRepository(),
              runtimeService: runtimeService,
              notificationBadgeService: notificationBadgeService,
              preferencesStore: preferencesStore,
            );
          },
          act: (bloc) async {
            bloc.add(
              const NotificationCenterStartedRequested(
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
              (state) => state.entries.first.event,
              "entry event type",
              isA<MentionedRuntimeNotificationEvent>(),
            ),
          ],
        );

        blocTest<NotificationCenterBloc, NotificationCenterState>(
          "Scenario: Friend-joined-voice event is suppressed by default",
          build: () {
            return _buildBloc(
              notificationRepo: FakeNotificationRepository(),
              runtimeService: runtimeService,
              notificationBadgeService: notificationBadgeService,
              preferencesStore: preferencesStore,
            );
          },
          act: (bloc) async {
            bloc.add(
              const NotificationCenterStartedRequested(
                bearerToken: "token",
              ),
            );

            await Future<void>.delayed(const Duration(milliseconds: 1));

            runtimeService.emit(
              const FriendJoinedVoiceRuntimeNotificationEvent(
                serverId: "server-1",
                serverName: "Server",
                channelId: "voice-allowed",
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
          "Scenario: Friend-joined-voice event is shown when enabled and selected",
          build: () {
            return _buildBloc(
              notificationRepo: FakeNotificationRepository(),
              runtimeService: runtimeService,
              notificationBadgeService: notificationBadgeService,
              preferencesStore: preferencesStore,
            );
          },
          act: (bloc) async {
            await preferencesStore.writeChannelJoinNotificationsEnabled(true);
            await preferencesStore.writeChannelJoinNotificationChannelIds(
              const <String>["voice-allowed"],
            );

            bloc.add(
              const NotificationCenterStartedRequested(
                bearerToken: "token",
              ),
            );

            await Future<void>.delayed(const Duration(milliseconds: 1));

            runtimeService.emit(
              const FriendJoinedVoiceRuntimeNotificationEvent(
                serverId: "server-1",
                serverName: "Server",
                channelId: "voice-allowed",
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
              (state) => state.entries.first.event,
              "entry event type",
              isA<FriendJoinedVoiceRuntimeNotificationEvent>(),
            ),
          ],
        );

        blocTest<NotificationCenterBloc, NotificationCenterState>(
          "Scenario: Unread count syncs to badge service",
          build: () {
            return _buildBloc(
              notificationRepo: FakeNotificationRepository(totalUnreadCount: 5),
              runtimeService: runtimeService,
              notificationBadgeService: notificationBadgeService,
              preferencesStore: preferencesStore,
            );
          },
          act: (bloc) {
            bloc.add(
              const NotificationCenterStartedRequested(
                bearerToken: "token",
              ),
            );
          },
          expect: () => <Matcher>[
            isA<NotificationCenterLoadedState>().having(
              (state) => state.totalUnreadCount,
              "total unread count",
              5,
            ),
          ],
          verify: (_) {
            expect(notificationBadgeService.syncedUnreadCounts, <int>[5]);
          },
        );

        blocTest<NotificationCenterBloc, NotificationCenterState>(
          "Scenario: Event outside selected channels is not shown in feed",
          build: () {
            return _buildBloc(
              notificationRepo: FakeNotificationRepository(),
              runtimeService: runtimeService,
              notificationBadgeService: notificationBadgeService,
              preferencesStore: preferencesStore,
            );
          },
          act: (bloc) async {
            await preferencesStore.writeChannelJoinNotificationsEnabled(true);
            await preferencesStore.writeChannelJoinNotificationChannelIds(
              const <String>["voice-allowed"],
            );

            bloc.add(
              const NotificationCenterStartedRequested(
                bearerToken: "token",
              ),
            );

            await Future<void>.delayed(const Duration(milliseconds: 1));

            runtimeService.emit(
              const FriendJoinedVoiceRuntimeNotificationEvent(
                serverId: "server-1",
                serverName: "Server",
                channelId: "voice-blocked",
                channelName: "Blocked",
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
          "Scenario: Event in selected channels is shown in feed",
          build: () {
            return _buildBloc(
              notificationRepo: FakeNotificationRepository(),
              runtimeService: runtimeService,
              notificationBadgeService: notificationBadgeService,
              preferencesStore: preferencesStore,
            );
          },
          act: (bloc) async {
            await preferencesStore.writeChannelJoinNotificationsEnabled(true);
            await preferencesStore.writeChannelJoinNotificationChannelIds(
              const <String>["voice-allowed"],
            );

            bloc.add(
              const NotificationCenterStartedRequested(
                bearerToken: "token",
              ),
            );

            await Future<void>.delayed(const Duration(milliseconds: 1));

            runtimeService.emit(
              const FriendJoinedVoiceRuntimeNotificationEvent(
                serverId: "server-1",
                serverName: "Server",
                channelId: "voice-allowed",
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
      },
    );
  });
}
