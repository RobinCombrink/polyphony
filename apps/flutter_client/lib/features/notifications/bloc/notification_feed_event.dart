part of "notification_feed_bloc.dart";

sealed class NotificationFeedEvent {
  const NotificationFeedEvent();
}

final class NotificationFeedRuntimeEventReceived extends NotificationFeedEvent {
  const NotificationFeedRuntimeEventReceived({
    required this.event,
  });

  final RuntimeNotificationEvent event;
}

final class NotificationFeedClearedRequested extends NotificationFeedEvent {
  const NotificationFeedClearedRequested();
}
