part of "notification_center_bloc.dart";

sealed class NotificationCenterEvent {
  const NotificationCenterEvent();
}

final class NotificationCenterStartedRequested extends NotificationCenterEvent {
  const NotificationCenterStartedRequested({
    required this.bearerToken,
  });

  final String bearerToken;
}

final class NotificationCenterUnreadCountRefreshRequested
    extends NotificationCenterEvent {
  const NotificationCenterUnreadCountRefreshRequested();
}

final class NotificationCenterFeedClearedRequested
    extends NotificationCenterEvent {
  const NotificationCenterFeedClearedRequested();
}

final class _NotificationCenterRuntimeEventReceived
    extends NotificationCenterEvent {
  const _NotificationCenterRuntimeEventReceived({
    required this.event,
  });

  final RuntimeNotificationEvent event;
}
