part of "settings_bloc.dart";

sealed class SettingsState {
  const SettingsState();
}

final class SettingsInitialState extends SettingsState {
  const SettingsInitialState();
}

sealed class SettingsLoadedDataState extends SettingsState {
  const SettingsLoadedDataState({
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

  SettingsExceptionState toException({required Exception error}) {
    return SettingsExceptionState(
      error: error,
      isDeveloperModeEnabled: isDeveloperModeEnabled,
      isDarkModeEnabled: isDarkModeEnabled,
      isChannelJoinNotificationsEnabled: isChannelJoinNotificationsEnabled,
      channelJoinNotificationChannelIds: channelJoinNotificationChannelIds,
      audioInputDevices: audioInputDevices,
      audioOutputDevices: audioOutputDevices,
      selectedAudioInputDeviceId: selectedAudioInputDeviceId,
      selectedAudioOutputDeviceId: selectedAudioOutputDeviceId,
    );
  }
}

final class SettingsLoadedState extends SettingsLoadedDataState {
  const SettingsLoadedState({
    required super.isDeveloperModeEnabled,
    required super.isDarkModeEnabled,
    required super.isChannelJoinNotificationsEnabled,
    required super.channelJoinNotificationChannelIds,
    required super.audioInputDevices,
    required super.audioOutputDevices,
    required super.selectedAudioInputDeviceId,
    required super.selectedAudioOutputDeviceId,
  });
}

final class SettingsExceptionState extends SettingsLoadedDataState {
  const SettingsExceptionState({
    required this.error,
    required super.isDeveloperModeEnabled,
    required super.isDarkModeEnabled,
    required super.isChannelJoinNotificationsEnabled,
    required super.channelJoinNotificationChannelIds,
    required super.audioInputDevices,
    required super.audioOutputDevices,
    required super.selectedAudioInputDeviceId,
    required super.selectedAudioOutputDeviceId,
  });

  final Exception error;
}
