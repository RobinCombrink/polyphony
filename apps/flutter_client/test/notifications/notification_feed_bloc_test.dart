import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/notifications/bloc/notification_feed_bloc.dart";
import "package:polyphony_flutter_client/shared/services/notification_runtime_service.dart";

void main() {
  blocTest<NotificationFeedBloc, NotificationFeedState>(
    "adds runtime notifications to feed",
    build: NotificationFeedBloc.new,
    act: (bloc) {
      bloc.add(
        const NotificationFeedRuntimeEventReceived(
          event: RuntimeNotificationEvent(
            eventType: RuntimeNotificationEventType.mentioned,
            channelId: "channel-1",
            messageId: "message-1",
          ),
        ),
      );
    },
    expect: () => <Matcher>[
      isA<NotificationFeedLoadedState>().having(
        (state) => state.entries.length,
        "entries length",
        1,
      ),
    ],
  );

  blocTest<NotificationFeedBloc, NotificationFeedState>(
    "clears feed entries",
    build: NotificationFeedBloc.new,
    act: (bloc) {
      bloc
        ..add(
          const NotificationFeedRuntimeEventReceived(
            event: RuntimeNotificationEvent(
              eventType: RuntimeNotificationEventType.unreadMessage,
              channelId: "channel-1",
              messageId: "message-1",
            ),
          ),
        )
        ..add(const NotificationFeedClearedRequested());
    },
    expect: () => <Matcher>[
      isA<NotificationFeedLoadedState>(),
      isA<NotificationFeedLoadedState>().having(
        (state) => state.entries,
        "entries",
        isEmpty,
      ),
    ],
  );
}
