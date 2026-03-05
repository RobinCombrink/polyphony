part of "settings_bloc.dart";

sealed class SettingsState {
  const SettingsState();
}

final class SettingsInitialState extends SettingsState {
  const SettingsInitialState();
}

final class SettingsLoadedState extends SettingsState {
  const SettingsLoadedState({required this.isDarkModeEnabled});

  final bool isDarkModeEnabled;
}

final class SettingsExceptionState extends SettingsState {
  const SettingsExceptionState({
    required this.error,
    required this.isDarkModeEnabled,
  });

  final Exception error;
  final bool isDarkModeEnabled;
}
