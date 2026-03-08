part of "settings_bloc.dart";

sealed class SettingsState {
  const SettingsState();
}

final class SettingsInitialState extends SettingsState {
  const SettingsInitialState();
}

final class SettingsLoadedState extends SettingsState {
  const SettingsLoadedState({
    required this.isDarkModeEnabled,
    required this.isChannelJoinNotificationsEnabled,
  });

  final bool isDarkModeEnabled;
  final bool isChannelJoinNotificationsEnabled;
}

final class SettingsExceptionState extends SettingsState {
  const SettingsExceptionState({
    required this.error,
    required this.isDarkModeEnabled,
    required this.isChannelJoinNotificationsEnabled,
  });

  final Exception error;
  final bool isDarkModeEnabled;
  final bool isChannelJoinNotificationsEnabled;
}
