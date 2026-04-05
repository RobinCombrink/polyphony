part of "notification_preferences_bloc.dart";

sealed class NotificationPreferencesScope {
  const NotificationPreferencesScope();
}

final class NotificationPreferencesGlobalScope
    extends NotificationPreferencesScope {
  const NotificationPreferencesGlobalScope();
}

final class NotificationPreferencesServerScope
    extends NotificationPreferencesScope {
  const NotificationPreferencesServerScope({
    required this.serverId,
    required this.serverPreference,
  });

  final String serverId;
  final ApiNotificationServerPreference? serverPreference;
}

final class NotificationPreferencesChannelScope
    extends NotificationPreferencesScope {
  const NotificationPreferencesChannelScope({
    required this.channelId,
    required this.channelPreference,
  });

  final String channelId;
  final ApiNotificationChannelPreference? channelPreference;
}

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
    required this.scope,
  });

  final ApiNotificationGlobalPreference globalPreference;
  final NotificationPreferencesScope scope;

  NotificationPreferencesLoadingState toLoading() {
    return NotificationPreferencesLoadingState(
      globalPreference: globalPreference,
      scope: scope,
    );
  }

  NotificationPreferencesExceptionState toException({
    required Exception error,
  }) {
    return NotificationPreferencesExceptionState(
      error: error,
      globalPreference: globalPreference,
      scope: scope,
    );
  }
}

final class NotificationPreferencesLoadedState
    extends NotificationPreferencesLoadedDataState {
  const NotificationPreferencesLoadedState({
    required super.globalPreference,
    required super.scope,
  });
}

final class NotificationPreferencesLoadingState
    extends NotificationPreferencesLoadedDataState {
  const NotificationPreferencesLoadingState({
    required super.globalPreference,
    required super.scope,
  });
}

final class NotificationPreferencesExceptionState
    extends NotificationPreferencesLoadedDataState {
  const NotificationPreferencesExceptionState({
    required this.error,
    required super.globalPreference,
    required super.scope,
  });

  final Exception error;
}
