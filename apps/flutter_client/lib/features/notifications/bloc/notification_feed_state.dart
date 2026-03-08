part of "notification_feed_bloc.dart";

final class NotificationFeedEntry {
  const NotificationFeedEntry({
    required this.event,
    required this.receivedAt,
  });

  final RuntimeNotificationEvent event;
  final DateTime receivedAt;
}

sealed class NotificationFeedState {
  const NotificationFeedState({
    required this.entries,
  });

  final List<NotificationFeedEntry> entries;
}

final class NotificationFeedInitialState extends NotificationFeedState {
  const NotificationFeedInitialState()
      : super(entries: const <NotificationFeedEntry>[]);
}

final class NotificationFeedLoadedState extends NotificationFeedState {
  const NotificationFeedLoadedState({
    required super.entries,
  });
}
