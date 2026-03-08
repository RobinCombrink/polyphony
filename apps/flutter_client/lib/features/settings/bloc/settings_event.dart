part of "settings_bloc.dart";

sealed class SettingsEvent {
  const SettingsEvent();
}

final class SettingsPreferencesRestoreRequested extends SettingsEvent {
  const SettingsPreferencesRestoreRequested();
}

final class SettingsDarkModeToggledRequested extends SettingsEvent {
  const SettingsDarkModeToggledRequested({required this.enabled});

  final bool enabled;
}

final class SettingsChannelJoinNotificationsToggledRequested
    extends SettingsEvent {
  const SettingsChannelJoinNotificationsToggledRequested({
    required this.enabled,
  });

  final bool enabled;
}
