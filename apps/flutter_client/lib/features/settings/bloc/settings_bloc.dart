import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";

part "settings_event.dart";
part "settings_state.dart";

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc({
    required PreferencesStore preferencesStore,
  })  : _preferencesStore = preferencesStore,
        super(const SettingsInitialState()) {
    on<SettingsPreferencesRestoreRequested>(
      _onSettingsPreferencesRestoreRequested,
    );
    on<SettingsDarkModeToggledRequested>(_onSettingsDarkModeToggledRequested);
  }

  final PreferencesStore _preferencesStore;

  Future<void> _onSettingsPreferencesRestoreRequested(
    SettingsPreferencesRestoreRequested event,
    Emitter<SettingsState> emit,
  ) async {
    final previousDarkModeEnabled = switch (state) {
      SettingsLoadedState(:final isDarkModeEnabled) => isDarkModeEnabled,
      SettingsExceptionState(:final isDarkModeEnabled) => isDarkModeEnabled,
      _ => false,
    };

    try {
      final isDarkModeEnabled = await _preferencesStore.readDarkModeEnabled();
      emit(SettingsLoadedState(isDarkModeEnabled: isDarkModeEnabled));
    } on Exception catch (error) {
      emit(
        SettingsExceptionState(
          error: error,
          isDarkModeEnabled: previousDarkModeEnabled,
        ),
      );
    }
  }

  Future<void> _onSettingsDarkModeToggledRequested(
    SettingsDarkModeToggledRequested event,
    Emitter<SettingsState> emit,
  ) async {
    final nextDarkModeEnabled = event.enabled;

    emit(SettingsLoadedState(isDarkModeEnabled: nextDarkModeEnabled));

    try {
      await _preferencesStore.writeDarkModeEnabled(nextDarkModeEnabled);
    } on Exception catch (error) {
      emit(
        SettingsExceptionState(
          error: error,
          isDarkModeEnabled: nextDarkModeEnabled,
        ),
      );
    }
  }
}
