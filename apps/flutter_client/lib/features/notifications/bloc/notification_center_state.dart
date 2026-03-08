part of "notification_center_bloc.dart";

final class NotificationCenterEntry {
  const NotificationCenterEntry({
    required this.event,
    required this.receivedAt,
  });

  final RuntimeNotificationEvent event;
  final DateTime receivedAt;
}

sealed class NotificationCenterState {
  const NotificationCenterState({
    required this.entries,
    required this.totalUnreadCount,
  });

  final List<NotificationCenterEntry> entries;
  final int totalUnreadCount;
}

final class NotificationCenterInitialState extends NotificationCenterState {
  const NotificationCenterInitialState()
      : super(entries: const <NotificationCenterEntry>[], totalUnreadCount: 0);
}

final class NotificationCenterLoadedState extends NotificationCenterState {
  const NotificationCenterLoadedState({
    required super.entries,
    required super.totalUnreadCount,
  });
}

final class NotificationCenterExceptionState extends NotificationCenterState {
  const NotificationCenterExceptionState({
    required super.entries,
    required super.totalUnreadCount,
    required this.error,
  });

  final Exception error;
}
