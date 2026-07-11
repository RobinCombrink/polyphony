part of "notification_preferences_bloc.dart";

sealed class NotificationPreferencesEvent {
  const NotificationPreferencesEvent();
}

final class LoadNotificationPreferencesRequested
    extends NotificationPreferencesEvent {
  const LoadNotificationPreferencesRequested({
    required this.serverId,
    required this.channelId,
  });

  final ServerId? serverId;
  final ChannelId? channelId;
}

final class GlobalMuteToggledRequested extends NotificationPreferencesEvent {
  const GlobalMuteToggledRequested({
    required this.muted,
  });

  final bool muted;
}

final class GlobalNotificationCategoryChangedRequested
    extends NotificationPreferencesEvent {
  const GlobalNotificationCategoryChangedRequested({
    required this.notificationCategory,
  });

  final NotificationCategoryPreference notificationCategory;
}

final class GlobalChannelDefaultCategoryChangedRequested
    extends NotificationPreferencesEvent {
  const GlobalChannelDefaultCategoryChangedRequested({
    required this.channelDefaultCategory,
  });

  final NotificationCategoryPreference channelDefaultCategory;
}

final class ServerMuteToggledRequested extends NotificationPreferencesEvent {
  const ServerMuteToggledRequested({
    required this.serverId,
    required this.muted,
  });

  final ServerId serverId;
  final bool muted;
}

final class ServerNotificationCategoryChangedRequested
    extends NotificationPreferencesEvent {
  const ServerNotificationCategoryChangedRequested({
    required this.serverId,
    required this.notificationCategory,
  });

  final ServerId serverId;
  final NotificationCategoryPreference notificationCategory;
}

final class ChannelMuteToggledRequested extends NotificationPreferencesEvent {
  const ChannelMuteToggledRequested({
    required this.channelId,
    required this.muted,
  });

  final ChannelId channelId;
  final bool muted;
}

final class ChannelNotificationCategoryChangedRequested
    extends NotificationPreferencesEvent {
  const ChannelNotificationCategoryChangedRequested({
    required this.channelId,
    required this.notificationCategory,
  });

  final ChannelId channelId;
  final NotificationCategoryPreference notificationCategory;
}
