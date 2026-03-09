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

final class SettingsChannelJoinNotificationChannelsSetRequested
    extends SettingsEvent {
  const SettingsChannelJoinNotificationChannelsSetRequested({
    required this.channelIds,
  });

  final List<String> channelIds;
}

final class SettingsAudioDevicesRefreshRequested extends SettingsEvent {
  const SettingsAudioDevicesRefreshRequested();
}

final class SettingsAudioInputDeviceSetRequested extends SettingsEvent {
  const SettingsAudioInputDeviceSetRequested({
    required this.deviceId,
  });

  final String? deviceId;
}

final class SettingsAudioOutputDeviceSetRequested extends SettingsEvent {
  const SettingsAudioOutputDeviceSetRequested({
    required this.deviceId,
  });

  final String? deviceId;
}
