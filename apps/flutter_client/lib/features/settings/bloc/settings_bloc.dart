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
    on<SettingsChannelJoinNotificationsToggledRequested>(
      _onSettingsChannelJoinNotificationsToggledRequested,
    );
    on<SettingsChannelJoinNotificationChannelsSetRequested>(
      _onSettingsChannelJoinNotificationChannelsSetRequested,
    );
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
    final previousChannelJoinNotificationsEnabled = switch (state) {
      SettingsLoadedState(:final isChannelJoinNotificationsEnabled) =>
        isChannelJoinNotificationsEnabled,
      SettingsExceptionState(:final isChannelJoinNotificationsEnabled) =>
        isChannelJoinNotificationsEnabled,
      _ => false,
    };
    final previousChannelJoinNotificationChannelIds = switch (state) {
      SettingsLoadedState(:final channelJoinNotificationChannelIds) =>
        channelJoinNotificationChannelIds,
      SettingsExceptionState(:final channelJoinNotificationChannelIds) =>
        channelJoinNotificationChannelIds,
      _ => const <String>[],
    };

    try {
      final isDarkModeEnabled = await _preferencesStore.readDarkModeEnabled();
      final isChannelJoinNotificationsEnabled =
          await _preferencesStore.readChannelJoinNotificationsEnabled();
      final channelJoinNotificationChannelIds =
          await _preferencesStore.readChannelJoinNotificationChannelIds();
      emit(
        SettingsLoadedState(
          isDarkModeEnabled: isDarkModeEnabled,
          isChannelJoinNotificationsEnabled: isChannelJoinNotificationsEnabled,
          channelJoinNotificationChannelIds: channelJoinNotificationChannelIds,
        ),
      );
    } on Exception catch (error) {
      emit(
        SettingsExceptionState(
          error: error,
          isDarkModeEnabled: previousDarkModeEnabled,
          isChannelJoinNotificationsEnabled:
              previousChannelJoinNotificationsEnabled,
          channelJoinNotificationChannelIds:
              previousChannelJoinNotificationChannelIds,
        ),
      );
    }
  }

  Future<void> _onSettingsDarkModeToggledRequested(
    SettingsDarkModeToggledRequested event,
    Emitter<SettingsState> emit,
  ) async {
    final nextDarkModeEnabled = event.enabled;
    final currentChannelJoinNotificationsEnabled = switch (state) {
      SettingsLoadedState(:final isChannelJoinNotificationsEnabled) =>
        isChannelJoinNotificationsEnabled,
      SettingsExceptionState(:final isChannelJoinNotificationsEnabled) =>
        isChannelJoinNotificationsEnabled,
      _ => false,
    };
    final currentChannelJoinNotificationChannelIds = switch (state) {
      SettingsLoadedState(:final channelJoinNotificationChannelIds) =>
        channelJoinNotificationChannelIds,
      SettingsExceptionState(:final channelJoinNotificationChannelIds) =>
        channelJoinNotificationChannelIds,
      _ => const <String>[],
    };

    emit(
      SettingsLoadedState(
        isDarkModeEnabled: nextDarkModeEnabled,
        isChannelJoinNotificationsEnabled:
            currentChannelJoinNotificationsEnabled,
        channelJoinNotificationChannelIds:
            currentChannelJoinNotificationChannelIds,
      ),
    );

    try {
      await _preferencesStore.writeDarkModeEnabled(nextDarkModeEnabled);
    } on Exception catch (error) {
      emit(
        SettingsExceptionState(
          error: error,
          isDarkModeEnabled: nextDarkModeEnabled,
          isChannelJoinNotificationsEnabled:
              currentChannelJoinNotificationsEnabled,
          channelJoinNotificationChannelIds:
              currentChannelJoinNotificationChannelIds,
        ),
      );
    }
  }

  Future<void> _onSettingsChannelJoinNotificationsToggledRequested(
    SettingsChannelJoinNotificationsToggledRequested event,
    Emitter<SettingsState> emit,
  ) async {
    final nextChannelJoinNotificationsEnabled = event.enabled;
    final currentDarkModeEnabled = switch (state) {
      SettingsLoadedState(:final isDarkModeEnabled) => isDarkModeEnabled,
      SettingsExceptionState(:final isDarkModeEnabled) => isDarkModeEnabled,
      _ => false,
    };
    final currentChannelJoinNotificationChannelIds = switch (state) {
      SettingsLoadedState(:final channelJoinNotificationChannelIds) =>
        channelJoinNotificationChannelIds,
      SettingsExceptionState(:final channelJoinNotificationChannelIds) =>
        channelJoinNotificationChannelIds,
      _ => const <String>[],
    };

    emit(
      SettingsLoadedState(
        isDarkModeEnabled: currentDarkModeEnabled,
        isChannelJoinNotificationsEnabled: nextChannelJoinNotificationsEnabled,
        channelJoinNotificationChannelIds:
            currentChannelJoinNotificationChannelIds,
      ),
    );

    try {
      await _preferencesStore.writeChannelJoinNotificationsEnabled(
        nextChannelJoinNotificationsEnabled,
      );
    } on Exception catch (error) {
      emit(
        SettingsExceptionState(
          error: error,
          isDarkModeEnabled: currentDarkModeEnabled,
          isChannelJoinNotificationsEnabled:
              nextChannelJoinNotificationsEnabled,
          channelJoinNotificationChannelIds:
              currentChannelJoinNotificationChannelIds,
        ),
      );
    }
  }

  Future<void> _onSettingsChannelJoinNotificationChannelsSetRequested(
    SettingsChannelJoinNotificationChannelsSetRequested event,
    Emitter<SettingsState> emit,
  ) async {
    final nextChannelIds = event.channelIds
        .map((channelId) => channelId.trim())
        .where((channelId) => channelId.isNotEmpty)
        .toSet()
        .toList(growable: false);

    final currentDarkModeEnabled = switch (state) {
      SettingsLoadedState(:final isDarkModeEnabled) => isDarkModeEnabled,
      SettingsExceptionState(:final isDarkModeEnabled) => isDarkModeEnabled,
      _ => false,
    };
    final currentChannelJoinNotificationsEnabled = switch (state) {
      SettingsLoadedState(:final isChannelJoinNotificationsEnabled) =>
        isChannelJoinNotificationsEnabled,
      SettingsExceptionState(:final isChannelJoinNotificationsEnabled) =>
        isChannelJoinNotificationsEnabled,
      _ => false,
    };

    emit(
      SettingsLoadedState(
        isDarkModeEnabled: currentDarkModeEnabled,
        isChannelJoinNotificationsEnabled:
            currentChannelJoinNotificationsEnabled,
        channelJoinNotificationChannelIds: nextChannelIds,
      ),
    );

    try {
      await _preferencesStore.writeChannelJoinNotificationChannelIds(
        nextChannelIds,
      );
    } on Exception catch (error) {
      emit(
        SettingsExceptionState(
          error: error,
          isDarkModeEnabled: currentDarkModeEnabled,
          isChannelJoinNotificationsEnabled:
              currentChannelJoinNotificationsEnabled,
          channelJoinNotificationChannelIds: nextChannelIds,
        ),
      );
    }
  }
}
