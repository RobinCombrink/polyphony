part of "settings_developer_profile_bloc.dart";

sealed class SettingsDeveloperProfileEvent {
  const SettingsDeveloperProfileEvent();
}

final class SettingsDeveloperProfileLoadRequested
    extends SettingsDeveloperProfileEvent {
  const SettingsDeveloperProfileLoadRequested();
}
