part of "settings_developer_profile_bloc.dart";

sealed class SettingsDeveloperProfileState {
  const SettingsDeveloperProfileState();
}

final class SettingsDeveloperProfileInitialState
    extends SettingsDeveloperProfileState {
  const SettingsDeveloperProfileInitialState();
}

final class SettingsDeveloperProfileLoadingState
    extends SettingsDeveloperProfileState {
  const SettingsDeveloperProfileLoadingState();
}

final class SettingsDeveloperProfileLoadedState
    extends SettingsDeveloperProfileState {
  const SettingsDeveloperProfileLoadedState({required this.me});

  final ApiMe me;
}

final class SettingsDeveloperProfileExceptionState
    extends SettingsDeveloperProfileState {
  const SettingsDeveloperProfileExceptionState({required this.error});

  final Exception error;
}
