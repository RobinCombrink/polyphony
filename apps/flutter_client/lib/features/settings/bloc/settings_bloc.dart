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
    final previousSnapshot = _snapshotFromState(state);

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
          await _readAudioInputDevices(previousSnapshot.audioInputDevices);
      final audioOutputDevices =
          await _readAudioOutputDevices(previousSnapshot.audioOutputDevices);
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
      emit(
        SettingsExceptionState(
          error: error,
          isDeveloperModeEnabled: previousSnapshot.isDeveloperModeEnabled,
          isDarkModeEnabled: previousSnapshot.isDarkModeEnabled,
          isChannelJoinNotificationsEnabled:
              previousSnapshot.isChannelJoinNotificationsEnabled,
          channelJoinNotificationChannelIds:
              previousSnapshot.channelJoinNotificationChannelIds,
          audioInputDevices: previousSnapshot.audioInputDevices,
          audioOutputDevices: previousSnapshot.audioOutputDevices,
          selectedAudioInputDeviceId:
              previousSnapshot.selectedAudioInputDeviceId,
          selectedAudioOutputDeviceId:
              previousSnapshot.selectedAudioOutputDeviceId,
        ),
      );
    }
  }

  Future<void> _onSettingsDeveloperModeToggledRequested(
    SettingsDeveloperModeToggledRequested event,
    Emitter<SettingsState> emit,
  ) async {
    final nextDeveloperModeEnabled = event.enabled;
    final currentSnapshot = _snapshotFromState(state);

    emit(
      SettingsLoadedState(
        isDeveloperModeEnabled: nextDeveloperModeEnabled,
        isDarkModeEnabled: currentSnapshot.isDarkModeEnabled,
        isChannelJoinNotificationsEnabled:
            currentSnapshot.isChannelJoinNotificationsEnabled,
        channelJoinNotificationChannelIds:
            currentSnapshot.channelJoinNotificationChannelIds,
        audioInputDevices: currentSnapshot.audioInputDevices,
        audioOutputDevices: currentSnapshot.audioOutputDevices,
        selectedAudioInputDeviceId: currentSnapshot.selectedAudioInputDeviceId,
        selectedAudioOutputDeviceId:
            currentSnapshot.selectedAudioOutputDeviceId,
      ),
    );

    try {
      await _preferencesStore
          .writeDeveloperModeEnabled(nextDeveloperModeEnabled);
    } on Exception catch (error) {
      emit(
        SettingsExceptionState(
          error: error,
          isDeveloperModeEnabled: nextDeveloperModeEnabled,
          isDarkModeEnabled: currentSnapshot.isDarkModeEnabled,
          isChannelJoinNotificationsEnabled:
              currentSnapshot.isChannelJoinNotificationsEnabled,
          channelJoinNotificationChannelIds:
              currentSnapshot.channelJoinNotificationChannelIds,
          audioInputDevices: currentSnapshot.audioInputDevices,
          audioOutputDevices: currentSnapshot.audioOutputDevices,
          selectedAudioInputDeviceId:
              currentSnapshot.selectedAudioInputDeviceId,
          selectedAudioOutputDeviceId:
              currentSnapshot.selectedAudioOutputDeviceId,
        ),
      );
    }
  }

  Future<void> _onSettingsDarkModeToggledRequested(
    SettingsDarkModeToggledRequested event,
    Emitter<SettingsState> emit,
  ) async {
    final nextDarkModeEnabled = event.enabled;
    final currentSnapshot = _snapshotFromState(state);

    emit(
      SettingsLoadedState(
        isDeveloperModeEnabled: currentSnapshot.isDeveloperModeEnabled,
        isDarkModeEnabled: nextDarkModeEnabled,
        isChannelJoinNotificationsEnabled:
            currentSnapshot.isChannelJoinNotificationsEnabled,
        channelJoinNotificationChannelIds:
            currentSnapshot.channelJoinNotificationChannelIds,
        audioInputDevices: currentSnapshot.audioInputDevices,
        audioOutputDevices: currentSnapshot.audioOutputDevices,
        selectedAudioInputDeviceId: currentSnapshot.selectedAudioInputDeviceId,
        selectedAudioOutputDeviceId:
            currentSnapshot.selectedAudioOutputDeviceId,
      ),
    );

    try {
      await _preferencesStore.writeDarkModeEnabled(nextDarkModeEnabled);
    } on Exception catch (error) {
      emit(
        SettingsExceptionState(
          error: error,
          isDeveloperModeEnabled: currentSnapshot.isDeveloperModeEnabled,
          isDarkModeEnabled: nextDarkModeEnabled,
          isChannelJoinNotificationsEnabled:
              currentSnapshot.isChannelJoinNotificationsEnabled,
          channelJoinNotificationChannelIds:
              currentSnapshot.channelJoinNotificationChannelIds,
          audioInputDevices: currentSnapshot.audioInputDevices,
          audioOutputDevices: currentSnapshot.audioOutputDevices,
          selectedAudioInputDeviceId:
              currentSnapshot.selectedAudioInputDeviceId,
          selectedAudioOutputDeviceId:
              currentSnapshot.selectedAudioOutputDeviceId,
        ),
      );
    }
  }

  Future<void> _onSettingsChannelJoinNotificationsToggledRequested(
    SettingsChannelJoinNotificationsToggledRequested event,
    Emitter<SettingsState> emit,
  ) async {
    final nextChannelJoinNotificationsEnabled = event.enabled;
    final currentSnapshot = _snapshotFromState(state);

    emit(
      SettingsLoadedState(
        isDeveloperModeEnabled: currentSnapshot.isDeveloperModeEnabled,
        isDarkModeEnabled: currentSnapshot.isDarkModeEnabled,
        isChannelJoinNotificationsEnabled: nextChannelJoinNotificationsEnabled,
        channelJoinNotificationChannelIds:
            currentSnapshot.channelJoinNotificationChannelIds,
        audioInputDevices: currentSnapshot.audioInputDevices,
        audioOutputDevices: currentSnapshot.audioOutputDevices,
        selectedAudioInputDeviceId: currentSnapshot.selectedAudioInputDeviceId,
        selectedAudioOutputDeviceId:
            currentSnapshot.selectedAudioOutputDeviceId,
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
          isDeveloperModeEnabled: currentSnapshot.isDeveloperModeEnabled,
          isDarkModeEnabled: currentSnapshot.isDarkModeEnabled,
          isChannelJoinNotificationsEnabled:
              nextChannelJoinNotificationsEnabled,
          channelJoinNotificationChannelIds:
              currentSnapshot.channelJoinNotificationChannelIds,
          audioInputDevices: currentSnapshot.audioInputDevices,
          audioOutputDevices: currentSnapshot.audioOutputDevices,
          selectedAudioInputDeviceId:
              currentSnapshot.selectedAudioInputDeviceId,
          selectedAudioOutputDeviceId:
              currentSnapshot.selectedAudioOutputDeviceId,
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

    final currentSnapshot = _snapshotFromState(state);

    emit(
      SettingsLoadedState(
        isDeveloperModeEnabled: currentSnapshot.isDeveloperModeEnabled,
        isDarkModeEnabled: currentSnapshot.isDarkModeEnabled,
        isChannelJoinNotificationsEnabled:
            currentSnapshot.isChannelJoinNotificationsEnabled,
        channelJoinNotificationChannelIds: nextChannelIds,
        audioInputDevices: currentSnapshot.audioInputDevices,
        audioOutputDevices: currentSnapshot.audioOutputDevices,
        selectedAudioInputDeviceId: currentSnapshot.selectedAudioInputDeviceId,
        selectedAudioOutputDeviceId:
            currentSnapshot.selectedAudioOutputDeviceId,
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
          isDeveloperModeEnabled: currentSnapshot.isDeveloperModeEnabled,
          isDarkModeEnabled: currentSnapshot.isDarkModeEnabled,
          isChannelJoinNotificationsEnabled:
              currentSnapshot.isChannelJoinNotificationsEnabled,
          channelJoinNotificationChannelIds: nextChannelIds,
          audioInputDevices: currentSnapshot.audioInputDevices,
          audioOutputDevices: currentSnapshot.audioOutputDevices,
          selectedAudioInputDeviceId:
              currentSnapshot.selectedAudioInputDeviceId,
          selectedAudioOutputDeviceId:
              currentSnapshot.selectedAudioOutputDeviceId,
        ),
      );
    }
  }

  Future<void> _onSettingsAudioDevicesRefreshRequested(
    SettingsAudioDevicesRefreshRequested event,
    Emitter<SettingsState> emit,
  ) async {
    final currentSnapshot = _snapshotFromState(state);

    try {
      final audioInputDevices =
          await _readAudioInputDevices(currentSnapshot.audioInputDevices);
      final audioOutputDevices =
          await _readAudioOutputDevices(currentSnapshot.audioOutputDevices);

      final selectedAudioInputDeviceId = _normalizeSelectedAudioDeviceId(
        selectedDeviceId:
            _audioDeviceRuntimeService.selectedAudioInputDeviceId() ??
                currentSnapshot.selectedAudioInputDeviceId,
        devices: audioInputDevices,
      );
      final selectedAudioOutputDeviceId = _normalizeSelectedAudioDeviceId(
        selectedDeviceId:
            _audioDeviceRuntimeService.selectedAudioOutputDeviceId() ??
                currentSnapshot.selectedAudioOutputDeviceId,
        devices: audioOutputDevices,
      );

      emit(
        SettingsLoadedState(
          isDeveloperModeEnabled: currentSnapshot.isDeveloperModeEnabled,
          isDarkModeEnabled: currentSnapshot.isDarkModeEnabled,
          isChannelJoinNotificationsEnabled:
              currentSnapshot.isChannelJoinNotificationsEnabled,
          channelJoinNotificationChannelIds:
              currentSnapshot.channelJoinNotificationChannelIds,
          audioInputDevices: audioInputDevices,
          audioOutputDevices: audioOutputDevices,
          selectedAudioInputDeviceId: selectedAudioInputDeviceId,
          selectedAudioOutputDeviceId: selectedAudioOutputDeviceId,
        ),
      );
    } on Exception catch (error) {
      emit(
        SettingsExceptionState(
          error: error,
          isDeveloperModeEnabled: currentSnapshot.isDeveloperModeEnabled,
          isDarkModeEnabled: currentSnapshot.isDarkModeEnabled,
          isChannelJoinNotificationsEnabled:
              currentSnapshot.isChannelJoinNotificationsEnabled,
          channelJoinNotificationChannelIds:
              currentSnapshot.channelJoinNotificationChannelIds,
          audioInputDevices: currentSnapshot.audioInputDevices,
          audioOutputDevices: currentSnapshot.audioOutputDevices,
          selectedAudioInputDeviceId:
              currentSnapshot.selectedAudioInputDeviceId,
          selectedAudioOutputDeviceId:
              currentSnapshot.selectedAudioOutputDeviceId,
        ),
      );
    }
  }

  Future<void> _onSettingsAudioInputDeviceSetRequested(
    SettingsAudioInputDeviceSetRequested event,
    Emitter<SettingsState> emit,
  ) async {
    final currentSnapshot = _snapshotFromState(state);
    final nextSelectedAudioInputDeviceId = _normalizeSelectedAudioDeviceId(
      selectedDeviceId: event.deviceId,
      devices: currentSnapshot.audioInputDevices,
    );

    emit(
      SettingsLoadedState(
        isDeveloperModeEnabled: currentSnapshot.isDeveloperModeEnabled,
        isDarkModeEnabled: currentSnapshot.isDarkModeEnabled,
        isChannelJoinNotificationsEnabled:
            currentSnapshot.isChannelJoinNotificationsEnabled,
        channelJoinNotificationChannelIds:
            currentSnapshot.channelJoinNotificationChannelIds,
        audioInputDevices: currentSnapshot.audioInputDevices,
        audioOutputDevices: currentSnapshot.audioOutputDevices,
        selectedAudioInputDeviceId: nextSelectedAudioInputDeviceId,
        selectedAudioOutputDeviceId:
            currentSnapshot.selectedAudioOutputDeviceId,
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
      emit(
        SettingsExceptionState(
          error: error,
          isDeveloperModeEnabled: currentSnapshot.isDeveloperModeEnabled,
          isDarkModeEnabled: currentSnapshot.isDarkModeEnabled,
          isChannelJoinNotificationsEnabled:
              currentSnapshot.isChannelJoinNotificationsEnabled,
          channelJoinNotificationChannelIds:
              currentSnapshot.channelJoinNotificationChannelIds,
          audioInputDevices: currentSnapshot.audioInputDevices,
          audioOutputDevices: currentSnapshot.audioOutputDevices,
          selectedAudioInputDeviceId:
              currentSnapshot.selectedAudioInputDeviceId,
          selectedAudioOutputDeviceId:
              currentSnapshot.selectedAudioOutputDeviceId,
        ),
      );
    }
  }

  Future<void> _onSettingsAudioOutputDeviceSetRequested(
    SettingsAudioOutputDeviceSetRequested event,
    Emitter<SettingsState> emit,
  ) async {
    final currentSnapshot = _snapshotFromState(state);
    final nextSelectedAudioOutputDeviceId = _normalizeSelectedAudioDeviceId(
      selectedDeviceId: event.deviceId,
      devices: currentSnapshot.audioOutputDevices,
    );

    emit(
      SettingsLoadedState(
        isDeveloperModeEnabled: currentSnapshot.isDeveloperModeEnabled,
        isDarkModeEnabled: currentSnapshot.isDarkModeEnabled,
        isChannelJoinNotificationsEnabled:
            currentSnapshot.isChannelJoinNotificationsEnabled,
        channelJoinNotificationChannelIds:
            currentSnapshot.channelJoinNotificationChannelIds,
        audioInputDevices: currentSnapshot.audioInputDevices,
        audioOutputDevices: currentSnapshot.audioOutputDevices,
        selectedAudioInputDeviceId: currentSnapshot.selectedAudioInputDeviceId,
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
      emit(
        SettingsExceptionState(
          error: error,
          isDeveloperModeEnabled: currentSnapshot.isDeveloperModeEnabled,
          isDarkModeEnabled: currentSnapshot.isDarkModeEnabled,
          isChannelJoinNotificationsEnabled:
              currentSnapshot.isChannelJoinNotificationsEnabled,
          channelJoinNotificationChannelIds:
              currentSnapshot.channelJoinNotificationChannelIds,
          audioInputDevices: currentSnapshot.audioInputDevices,
          audioOutputDevices: currentSnapshot.audioOutputDevices,
          selectedAudioInputDeviceId:
              currentSnapshot.selectedAudioInputDeviceId,
          selectedAudioOutputDeviceId:
              currentSnapshot.selectedAudioOutputDeviceId,
        ),
      );
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

  _SettingsSnapshot _snapshotFromState(SettingsState currentState) {
    return switch (currentState) {
      SettingsLoadedState(
        :final isDeveloperModeEnabled,
        :final isDarkModeEnabled,
        :final isChannelJoinNotificationsEnabled,
        :final channelJoinNotificationChannelIds,
        :final audioInputDevices,
        :final audioOutputDevices,
        :final selectedAudioInputDeviceId,
        :final selectedAudioOutputDeviceId,
      ) =>
        _SettingsSnapshot(
          isDeveloperModeEnabled: isDeveloperModeEnabled,
          isDarkModeEnabled: isDarkModeEnabled,
          isChannelJoinNotificationsEnabled: isChannelJoinNotificationsEnabled,
          channelJoinNotificationChannelIds: channelJoinNotificationChannelIds,
          audioInputDevices: audioInputDevices,
          audioOutputDevices: audioOutputDevices,
          selectedAudioInputDeviceId: selectedAudioInputDeviceId,
          selectedAudioOutputDeviceId: selectedAudioOutputDeviceId,
        ),
      SettingsExceptionState(
        :final isDeveloperModeEnabled,
        :final isDarkModeEnabled,
        :final isChannelJoinNotificationsEnabled,
        :final channelJoinNotificationChannelIds,
        :final audioInputDevices,
        :final audioOutputDevices,
        :final selectedAudioInputDeviceId,
        :final selectedAudioOutputDeviceId,
      ) =>
        _SettingsSnapshot(
          isDeveloperModeEnabled: isDeveloperModeEnabled,
          isDarkModeEnabled: isDarkModeEnabled,
          isChannelJoinNotificationsEnabled: isChannelJoinNotificationsEnabled,
          channelJoinNotificationChannelIds: channelJoinNotificationChannelIds,
          audioInputDevices: audioInputDevices,
          audioOutputDevices: audioOutputDevices,
          selectedAudioInputDeviceId: selectedAudioInputDeviceId,
          selectedAudioOutputDeviceId: selectedAudioOutputDeviceId,
        ),
      SettingsInitialState() => const _SettingsSnapshot(),
    };
  }
}

final class _SettingsSnapshot {
  const _SettingsSnapshot({
    this.isDeveloperModeEnabled = false,
    this.isDarkModeEnabled = false,
    this.isChannelJoinNotificationsEnabled = false,
    this.channelJoinNotificationChannelIds = const <String>[],
    this.audioInputDevices = const <RuntimeAudioDevice>[],
    this.audioOutputDevices = const <RuntimeAudioDevice>[],
    this.selectedAudioInputDeviceId,
    this.selectedAudioOutputDeviceId,
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
