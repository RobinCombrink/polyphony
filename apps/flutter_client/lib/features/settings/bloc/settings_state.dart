part of "settings_bloc.dart";

sealed class SettingsState {
  const SettingsState();
}

final class SettingsInitialState extends SettingsState {
  const SettingsInitialState();
}

final class SettingsLoadedState extends SettingsState {
  const SettingsLoadedState({
    required this.isDeveloperModeEnabled,
    required this.isDarkModeEnabled,
    required this.isChannelJoinNotificationsEnabled,
    required this.channelJoinNotificationChannelIds,
    required this.audioInputDevices,
    required this.audioOutputDevices,
    required this.selectedAudioInputDeviceId,
    required this.selectedAudioOutputDeviceId,
  });

  final bool isDeveloperModeEnabled;
  final bool isDarkModeEnabled;
  final bool isChannelJoinNotificationsEnabled;
  final List<String> channelJoinNotificationChannelIds;
  final List<RuntimeAudioDevice> audioInputDevices;
  final List<RuntimeAudioDevice> audioOutputDevices;
  final String? selectedAudioInputDeviceId;
  final String? selectedAudioOutputDeviceId;
}

final class SettingsExceptionState extends SettingsState {
  const SettingsExceptionState({
    required this.error,
    required this.isDeveloperModeEnabled,
    required this.isDarkModeEnabled,
    required this.isChannelJoinNotificationsEnabled,
    required this.channelJoinNotificationChannelIds,
    required this.audioInputDevices,
    required this.audioOutputDevices,
    required this.selectedAudioInputDeviceId,
    required this.selectedAudioOutputDeviceId,
  });

  final Exception error;
  final bool isDeveloperModeEnabled;
  final bool isDarkModeEnabled;
  final bool isChannelJoinNotificationsEnabled;
  final List<String> channelJoinNotificationChannelIds;
  final List<RuntimeAudioDevice> audioInputDevices;
  final List<RuntimeAudioDevice> audioOutputDevices;
  final String? selectedAudioInputDeviceId;
  final String? selectedAudioOutputDeviceId;
}
