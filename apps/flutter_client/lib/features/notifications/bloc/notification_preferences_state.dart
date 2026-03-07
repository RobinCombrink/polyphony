part of "notification_preferences_bloc.dart";

sealed class NotificationPreferencesState {
  const NotificationPreferencesState();
}

final class NotificationPreferencesInitialState
    extends NotificationPreferencesState {
  const NotificationPreferencesInitialState();
}

sealed class NotificationPreferencesLoadedDataState
    extends NotificationPreferencesState {
  const NotificationPreferencesLoadedDataState({
    required this.globalPreference,
    required this.serverId,
    required this.channelId,
    required this.serverPreference,
    required this.channelPreference,
  });

  final ApiNotificationGlobalPreference globalPreference;
  final String? serverId;
  final String? channelId;
  final ApiNotificationServerPreference? serverPreference;
  final ApiNotificationChannelPreference? channelPreference;
}

final class NotificationPreferencesLoadedState
    extends NotificationPreferencesLoadedDataState {
  const NotificationPreferencesLoadedState({
    required super.globalPreference,
    required super.serverId,
    required super.channelId,
    required super.serverPreference,
    required super.channelPreference,
  });
}

final class NotificationPreferencesLoadingState
    extends NotificationPreferencesLoadedDataState {
  const NotificationPreferencesLoadingState({
    required super.globalPreference,
    required super.serverId,
    required super.channelId,
    required super.serverPreference,
    required super.channelPreference,
  });
}

final class NotificationPreferencesExceptionState
    extends NotificationPreferencesLoadedDataState {
  const NotificationPreferencesExceptionState({
    required this.error,
    required super.globalPreference,
    required super.serverId,
    required super.channelId,
    required super.serverPreference,
    required super.channelPreference,
  });

  final Exception error;
}
