import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/audio_device_runtime_service.dart";
import "package:polyphony_flutter_client/shared/services/media_runtime_service.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";

part "settings_event.dart";
part "settings_state.dart";

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc({
    required PreferencesStore preferencesStore,
    required AudioDeviceRuntimeService audioDeviceRuntimeService,
  })  : _preferencesStore = preferencesStore,
        _audioDeviceRuntimeService = audioDeviceRuntimeService,
        super(const SettingsInitialState()) {
    on<SettingsPreferencesRestoreRequested>(
      _onSettingsPreferencesRestoreRequested,
    );
    on<SettingsDeveloperModeToggledRequested>(
      _onSettingsDeveloperModeToggledRequested,
    );
    on<SettingsDarkModeToggledRequested>(_onSettingsDarkModeToggledRequested);
    on<SettingsChannelJoinNotificationsToggledRequested>(
      _onSettingsChannelJoinNotificationsToggledRequested,
    );
    on<SettingsChannelJoinNotificationChannelsSetRequested>(
      _onSettingsChannelJoinNotificationChannelsSetRequested,
    );
    on<SettingsAudioDevicesRefreshRequested>(
      _onSettingsAudioDevicesRefreshRequested,
    );
    on<SettingsAudioInputDeviceSetRequested>(
      _onSettingsAudioInputDeviceSetRequested,
    );
    on<SettingsAudioOutputDeviceSetRequested>(
      _onSettingsAudioOutputDeviceSetRequested,
    );

    _audioDeviceChangesSubscription =
        _audioDeviceRuntimeService.audioDeviceChanges().listen((_) {
      add(const SettingsAudioDevicesRefreshRequested());
    });
  }

  final PreferencesStore _preferencesStore;
  final AudioDeviceRuntimeService _audioDeviceRuntimeService;
  StreamSubscription<void>? _audioDeviceChangesSubscription;

  @override
  Future<void> close() async {
    final audioDeviceChangesSubscription = _audioDeviceChangesSubscription;
    _audioDeviceChangesSubscription = null;
    if (audioDeviceChangesSubscription != null) {
      await audioDeviceChangesSubscription.cancel();
    }

    return super.close();
  }

  Future<void> _onSettingsPreferencesRestoreRequested(
    SettingsPreferencesRestoreRequested event,
    Emitter<SettingsState> emit,
  ) async {
    final previousState = _loadedDataStateOrDefault(state);

    try {
      final isDeveloperModeEnabled =
          await _preferencesStore.readDeveloperModeEnabled();
      final isDarkModeEnabled = await _preferencesStore.readDarkModeEnabled();
      final isChannelJoinNotificationsEnabled =
          await _preferencesStore.readChannelJoinNotificationsEnabled();
      final channelJoinNotificationChannelIds =
          await _preferencesStore.readChannelJoinNotificationChannelIds();
      final persistedAudioInputDeviceId =
          await _preferencesStore.readAudioInputDeviceId();
      final persistedAudioOutputDeviceId =
          await _preferencesStore.readAudioOutputDeviceId();

      final audioInputDevices =
          await _readAudioInputDevices(previousState.audioInputDevices);
      final audioOutputDevices =
          await _readAudioOutputDevices(previousState.audioOutputDevices);
      final selectedAudioInputDeviceId = _normalizeSelectedAudioDeviceId(
        selectedDeviceId: persistedAudioInputDeviceId,
        devices: audioInputDevices,
      );
      final selectedAudioOutputDeviceId = _normalizeSelectedAudioDeviceId(
        selectedDeviceId: persistedAudioOutputDeviceId,
        devices: audioOutputDevices,
      );

      await _applyAudioSelections(
        selectedAudioInputDeviceId: selectedAudioInputDeviceId,
        selectedAudioOutputDeviceId: selectedAudioOutputDeviceId,
      );

      emit(
        SettingsLoadedState(
          isDeveloperModeEnabled: isDeveloperModeEnabled,
          isDarkModeEnabled: isDarkModeEnabled,
          isChannelJoinNotificationsEnabled: isChannelJoinNotificationsEnabled,
          channelJoinNotificationChannelIds: channelJoinNotificationChannelIds,
          audioInputDevices: audioInputDevices,
          audioOutputDevices: audioOutputDevices,
          selectedAudioInputDeviceId: selectedAudioInputDeviceId,
          selectedAudioOutputDeviceId: selectedAudioOutputDeviceId,
        ),
      );
    } on Exception catch (error) {
      emit(previousState.toException(error: error));
    }
  }

  Future<void> _onSettingsDeveloperModeToggledRequested(
    SettingsDeveloperModeToggledRequested event,
    Emitter<SettingsState> emit,
  ) async {
    final nextDeveloperModeEnabled = event.enabled;
    final currentState = _loadedDataStateOrDefault(state);

    emit(
      SettingsLoadedState(
        isDeveloperModeEnabled: nextDeveloperModeEnabled,
        isDarkModeEnabled: currentState.isDarkModeEnabled,
        isChannelJoinNotificationsEnabled:
            currentState.isChannelJoinNotificationsEnabled,
        channelJoinNotificationChannelIds:
            currentState.channelJoinNotificationChannelIds,
        audioInputDevices: currentState.audioInputDevices,
        audioOutputDevices: currentState.audioOutputDevices,
        selectedAudioInputDeviceId: currentState.selectedAudioInputDeviceId,
        selectedAudioOutputDeviceId: currentState.selectedAudioOutputDeviceId,
      ),
    );

    try {
      await _preferencesStore
          .writeDeveloperModeEnabled(nextDeveloperModeEnabled);
    } on Exception catch (error) {
      emit(currentState.toException(error: error));
    }
  }

  Future<void> _onSettingsDarkModeToggledRequested(
    SettingsDarkModeToggledRequested event,
    Emitter<SettingsState> emit,
  ) async {
    final nextDarkModeEnabled = event.enabled;
    final currentState = _loadedDataStateOrDefault(state);

    emit(
      SettingsLoadedState(
        isDeveloperModeEnabled: currentState.isDeveloperModeEnabled,
        isDarkModeEnabled: nextDarkModeEnabled,
        isChannelJoinNotificationsEnabled:
            currentState.isChannelJoinNotificationsEnabled,
        channelJoinNotificationChannelIds:
            currentState.channelJoinNotificationChannelIds,
        audioInputDevices: currentState.audioInputDevices,
        audioOutputDevices: currentState.audioOutputDevices,
        selectedAudioInputDeviceId: currentState.selectedAudioInputDeviceId,
        selectedAudioOutputDeviceId: currentState.selectedAudioOutputDeviceId,
      ),
    );

    try {
      await _preferencesStore.writeDarkModeEnabled(nextDarkModeEnabled);
    } on Exception catch (error) {
      emit(currentState.toException(error: error));
    }
  }

  Future<void> _onSettingsChannelJoinNotificationsToggledRequested(
    SettingsChannelJoinNotificationsToggledRequested event,
    Emitter<SettingsState> emit,
  ) async {
    final nextChannelJoinNotificationsEnabled = event.enabled;
    final currentState = _loadedDataStateOrDefault(state);

    emit(
      SettingsLoadedState(
        isDeveloperModeEnabled: currentState.isDeveloperModeEnabled,
        isDarkModeEnabled: currentState.isDarkModeEnabled,
        isChannelJoinNotificationsEnabled: nextChannelJoinNotificationsEnabled,
        channelJoinNotificationChannelIds:
            currentState.channelJoinNotificationChannelIds,
        audioInputDevices: currentState.audioInputDevices,
        audioOutputDevices: currentState.audioOutputDevices,
        selectedAudioInputDeviceId: currentState.selectedAudioInputDeviceId,
        selectedAudioOutputDeviceId: currentState.selectedAudioOutputDeviceId,
      ),
    );

    try {
      await _preferencesStore.writeChannelJoinNotificationsEnabled(
        nextChannelJoinNotificationsEnabled,
      );
    } on Exception catch (error) {
      emit(currentState.toException(error: error));
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

    final currentState = _loadedDataStateOrDefault(state);

    emit(
      SettingsLoadedState(
        isDeveloperModeEnabled: currentState.isDeveloperModeEnabled,
        isDarkModeEnabled: currentState.isDarkModeEnabled,
        isChannelJoinNotificationsEnabled:
            currentState.isChannelJoinNotificationsEnabled,
        channelJoinNotificationChannelIds: nextChannelIds,
        audioInputDevices: currentState.audioInputDevices,
        audioOutputDevices: currentState.audioOutputDevices,
        selectedAudioInputDeviceId: currentState.selectedAudioInputDeviceId,
        selectedAudioOutputDeviceId: currentState.selectedAudioOutputDeviceId,
      ),
    );

    try {
      await _preferencesStore.writeChannelJoinNotificationChannelIds(
        nextChannelIds,
      );
    } on Exception catch (error) {
      emit(currentState.toException(error: error));
    }
  }

  Future<void> _onSettingsAudioDevicesRefreshRequested(
    SettingsAudioDevicesRefreshRequested event,
    Emitter<SettingsState> emit,
  ) async {
    final currentState = _loadedDataStateOrDefault(state);

    try {
      final audioInputDevices =
          await _readAudioInputDevices(currentState.audioInputDevices);
      final audioOutputDevices =
          await _readAudioOutputDevices(currentState.audioOutputDevices);

      final selectedAudioInputDeviceId = _normalizeSelectedAudioDeviceId(
        selectedDeviceId:
            _audioDeviceRuntimeService.selectedAudioInputDeviceId() ??
                currentState.selectedAudioInputDeviceId,
        devices: audioInputDevices,
      );
      final selectedAudioOutputDeviceId = _normalizeSelectedAudioDeviceId(
        selectedDeviceId:
            _audioDeviceRuntimeService.selectedAudioOutputDeviceId() ??
                currentState.selectedAudioOutputDeviceId,
        devices: audioOutputDevices,
      );

      emit(
        SettingsLoadedState(
          isDeveloperModeEnabled: currentState.isDeveloperModeEnabled,
          isDarkModeEnabled: currentState.isDarkModeEnabled,
          isChannelJoinNotificationsEnabled:
              currentState.isChannelJoinNotificationsEnabled,
          channelJoinNotificationChannelIds:
              currentState.channelJoinNotificationChannelIds,
          audioInputDevices: audioInputDevices,
          audioOutputDevices: audioOutputDevices,
          selectedAudioInputDeviceId: selectedAudioInputDeviceId,
          selectedAudioOutputDeviceId: selectedAudioOutputDeviceId,
        ),
      );
    } on Exception catch (error) {
      emit(currentState.toException(error: error));
    }
  }

  Future<void> _onSettingsAudioInputDeviceSetRequested(
    SettingsAudioInputDeviceSetRequested event,
    Emitter<SettingsState> emit,
  ) async {
    final currentState = _loadedDataStateOrDefault(state);
    final nextSelectedAudioInputDeviceId = _normalizeSelectedAudioDeviceId(
      selectedDeviceId: event.deviceId,
      devices: currentState.audioInputDevices,
    );

    emit(
      SettingsLoadedState(
        isDeveloperModeEnabled: currentState.isDeveloperModeEnabled,
        isDarkModeEnabled: currentState.isDarkModeEnabled,
        isChannelJoinNotificationsEnabled:
            currentState.isChannelJoinNotificationsEnabled,
        channelJoinNotificationChannelIds:
            currentState.channelJoinNotificationChannelIds,
        audioInputDevices: currentState.audioInputDevices,
        audioOutputDevices: currentState.audioOutputDevices,
        selectedAudioInputDeviceId: nextSelectedAudioInputDeviceId,
        selectedAudioOutputDeviceId: currentState.selectedAudioOutputDeviceId,
      ),
    );

    try {
      final applyResult = await _audioDeviceRuntimeService
          .setSelectedAudioInputDeviceId(nextSelectedAudioInputDeviceId);
      if (applyResult case Error<void>(:final error)) {
        throw error;
      }

      await _preferencesStore
          .writeAudioInputDeviceId(nextSelectedAudioInputDeviceId);
    } on Exception catch (error) {
      emit(currentState.toException(error: error));
    }
  }

  Future<void> _onSettingsAudioOutputDeviceSetRequested(
    SettingsAudioOutputDeviceSetRequested event,
    Emitter<SettingsState> emit,
  ) async {
    final currentState = _loadedDataStateOrDefault(state);
    final nextSelectedAudioOutputDeviceId = _normalizeSelectedAudioDeviceId(
      selectedDeviceId: event.deviceId,
      devices: currentState.audioOutputDevices,
    );

    emit(
      SettingsLoadedState(
        isDeveloperModeEnabled: currentState.isDeveloperModeEnabled,
        isDarkModeEnabled: currentState.isDarkModeEnabled,
        isChannelJoinNotificationsEnabled:
            currentState.isChannelJoinNotificationsEnabled,
        channelJoinNotificationChannelIds:
            currentState.channelJoinNotificationChannelIds,
        audioInputDevices: currentState.audioInputDevices,
        audioOutputDevices: currentState.audioOutputDevices,
        selectedAudioInputDeviceId: currentState.selectedAudioInputDeviceId,
        selectedAudioOutputDeviceId: nextSelectedAudioOutputDeviceId,
      ),
    );

    try {
      final applyResult = await _audioDeviceRuntimeService
          .setSelectedAudioOutputDeviceId(nextSelectedAudioOutputDeviceId);
      if (applyResult case Error<void>(:final error)) {
        throw error;
      }

      await _preferencesStore
          .writeAudioOutputDeviceId(nextSelectedAudioOutputDeviceId);
    } on Exception catch (error) {
      emit(currentState.toException(error: error));
    }
  }

  Future<List<RuntimeAudioDevice>> _readAudioInputDevices(
    List<RuntimeAudioDevice> fallback,
  ) async {
    final result = await _audioDeviceRuntimeService.listAudioInputDevices();
    return switch (result) {
      Ok<List<RuntimeAudioDevice>>(:final value) => value,
      Error<List<RuntimeAudioDevice>>() => fallback,
    };
  }

  Future<List<RuntimeAudioDevice>> _readAudioOutputDevices(
    List<RuntimeAudioDevice> fallback,
  ) async {
    final result = await _audioDeviceRuntimeService.listAudioOutputDevices();
    return switch (result) {
      Ok<List<RuntimeAudioDevice>>(:final value) => value,
      Error<List<RuntimeAudioDevice>>() => fallback,
    };
  }

  String? _normalizeSelectedAudioDeviceId({
    required String? selectedDeviceId,
    required List<RuntimeAudioDevice> devices,
  }) {
    final trimmedSelectedDeviceId = selectedDeviceId?.trim();
    if (trimmedSelectedDeviceId == null || trimmedSelectedDeviceId.isEmpty) {
      return null;
    }

    final hasSelectedDevice =
        devices.any((device) => device.id == trimmedSelectedDeviceId);
    return hasSelectedDevice ? trimmedSelectedDeviceId : null;
  }

  Future<void> _applyAudioSelections({
    required String? selectedAudioInputDeviceId,
    required String? selectedAudioOutputDeviceId,
  }) async {
    final applyInputResult = await _audioDeviceRuntimeService
        .setSelectedAudioInputDeviceId(selectedAudioInputDeviceId);
    if (applyInputResult case Error<void>(:final error)) {
      throw error;
    }

    final applyOutputResult = await _audioDeviceRuntimeService
        .setSelectedAudioOutputDeviceId(selectedAudioOutputDeviceId);
    if (applyOutputResult case Error<void>(:final error)) {
      throw error;
    }
  }

  SettingsLoadedDataState _loadedDataStateOrDefault(
    SettingsState currentState,
  ) {
    return switch (currentState) {
      final SettingsLoadedDataState loadedState => loadedState,
      SettingsInitialState() => const SettingsLoadedState(
          isDeveloperModeEnabled: false,
          isDarkModeEnabled: false,
          isChannelJoinNotificationsEnabled: false,
          channelJoinNotificationChannelIds: <String>[],
          audioInputDevices: <RuntimeAudioDevice>[],
          audioOutputDevices: <RuntimeAudioDevice>[],
          selectedAudioInputDeviceId: null,
          selectedAudioOutputDeviceId: null,
        ),
    };
  }
}
