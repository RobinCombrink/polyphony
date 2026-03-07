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

  final String? serverId;
  final String? channelId;
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

  final ApiNotificationCategoryPreference notificationCategory;
}

final class GlobalChannelDefaultCategoryChangedRequested
    extends NotificationPreferencesEvent {
  const GlobalChannelDefaultCategoryChangedRequested({
    required this.channelDefaultCategory,
  });

  final ApiNotificationCategoryPreference channelDefaultCategory;
}

final class ServerMuteToggledRequested extends NotificationPreferencesEvent {
  const ServerMuteToggledRequested({
    required this.serverId,
    required this.muted,
  });

  final String serverId;
  final bool muted;
}

final class ServerNotificationCategoryChangedRequested
    extends NotificationPreferencesEvent {
  const ServerNotificationCategoryChangedRequested({
    required this.serverId,
    required this.notificationCategory,
  });

  final String serverId;
  final ApiNotificationCategoryPreference notificationCategory;
}

final class ChannelMuteToggledRequested extends NotificationPreferencesEvent {
  const ChannelMuteToggledRequested({
    required this.channelId,
    required this.muted,
  });

  final String channelId;
  final bool muted;
}

final class ChannelNotificationCategoryChangedRequested
    extends NotificationPreferencesEvent {
  const ChannelNotificationCategoryChangedRequested({
    required this.channelId,
    required this.notificationCategory,
  });

  final String channelId;
  final ApiNotificationCategoryPreference notificationCategory;
}
