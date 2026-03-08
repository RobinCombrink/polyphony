part of "notification_unread_count_bloc.dart";

sealed class NotificationUnreadCountEvent {
  const NotificationUnreadCountEvent();
}

final class LoadNotificationUnreadCountRequested
    extends NotificationUnreadCountEvent {
  const LoadNotificationUnreadCountRequested();
}
