part of "notification_unread_count_bloc.dart";

sealed class NotificationUnreadCountState {
  const NotificationUnreadCountState();

  int totalUnreadCountOrZero() {
    return switch (this) {
      NotificationUnreadCountLoadedState(:final totalUnreadCount) =>
        totalUnreadCount,
      NotificationUnreadCountExceptionState(:final lastKnownTotalUnreadCount) =>
        lastKnownTotalUnreadCount,
      _ => 0,
    };
  }
}

final class NotificationUnreadCountInitialState
    extends NotificationUnreadCountState {
  const NotificationUnreadCountInitialState();
}

final class NotificationUnreadCountLoadedState
    extends NotificationUnreadCountState {
  const NotificationUnreadCountLoadedState({
    required this.totalUnreadCount,
  });

  final int totalUnreadCount;
}

final class NotificationUnreadCountExceptionState
    extends NotificationUnreadCountState {
  const NotificationUnreadCountExceptionState({
    required this.error,
    required this.lastKnownTotalUnreadCount,
  });

  final Exception error;
  final int lastKnownTotalUnreadCount;
}
