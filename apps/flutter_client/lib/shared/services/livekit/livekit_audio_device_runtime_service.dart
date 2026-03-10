import "dart:async";

import "package:collection/collection.dart";
import "package:livekit_client/livekit_client.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/audio_device_runtime_service.dart";
import "package:polyphony_flutter_client/shared/services/media_runtime_service.dart";

class LivekitAudioDeviceRuntimeService implements AudioDeviceRuntimeService {
  LivekitAudioDeviceRuntimeService({
    Room? Function()? activeRoom,
  }) : _activeRoom = activeRoom ?? _inactiveRoom {
    _deviceChangeSubscription =
        Hardware.instance.onDeviceChange.stream.listen((_) {
      _audioDeviceChangesController.add(null);
    });
  }

  Room? Function() _activeRoom;
  final _audioDeviceChangesController = StreamController<void>.broadcast();
  late final StreamSubscription<List<MediaDevice>> _deviceChangeSubscription;

  var _operationQueue = Future<void>.value();
  String? _selectedAudioInputDeviceId;
  String? _selectedAudioOutputDeviceId;

  @override
  Future<Result<List<RuntimeAudioDevice>>> listAudioInputDevices() async {
    try {
      final devices = await Hardware.instance.audioInputs();
      final systemDefaultDeviceId = _resolveSystemDefaultDeviceId(
        devices: devices,
        kind: "audioinput",
      );
      return Ok<List<RuntimeAudioDevice>>(
        _toRuntimeAudioDevices(
          devices: devices,
          systemDefaultDeviceId: systemDefaultDeviceId,
        ),
      );
    } on Exception catch (error) {
      return Error<List<RuntimeAudioDevice>>(error);
    }
  }

  @override
  Future<Result<List<RuntimeAudioDevice>>> listAudioOutputDevices() async {
    try {
      final devices = await Hardware.instance.audioOutputs();
      final systemDefaultDeviceId = _resolveSystemDefaultDeviceId(
        devices: devices,
        kind: "audiooutput",
      );
      return Ok<List<RuntimeAudioDevice>>(
        _toRuntimeAudioDevices(
          devices: devices,
          systemDefaultDeviceId: systemDefaultDeviceId,
        ),
      );
    } on Exception catch (error) {
      return Error<List<RuntimeAudioDevice>>(error);
    }
  }

  @override
  Future<Result<void>> setSelectedAudioInputDeviceId(String? deviceId) {
    return _enqueue(() async {
      final normalizedDeviceId = _normalizeDeviceId(deviceId);
      _selectedAudioInputDeviceId = normalizedDeviceId;

      if (normalizedDeviceId == null) {
        return const Ok<void>(null);
      }

      final inputDevicesResult = await listAudioInputDevices();
      if (inputDevicesResult
          case Error<List<RuntimeAudioDevice>>(:final error)) {
        return Error<void>(error);
      }

      final inputDevices =
          (inputDevicesResult as Ok<List<RuntimeAudioDevice>>).value;
      final selectedInputDevice = inputDevices
          .where((device) => device.id == normalizedDeviceId)
          .firstOrNull;
      if (selectedInputDevice == null) {
        return Error<void>(
          Exception("Unknown audio input device id: $normalizedDeviceId"),
        );
      }

      final room = _activeRoom();
      if (room == null) {
        return const Ok<void>(null);
      }

      await room.setAudioInputDevice(
        MediaDevice(
          selectedInputDevice.id,
          selectedInputDevice.label,
          "audioinput",
          null,
        ),
      );

      return const Ok<void>(null);
    });
  }

  @override
  Future<Result<void>> setSelectedAudioOutputDeviceId(String? deviceId) {
    return _enqueue(() async {
      final normalizedDeviceId = _normalizeDeviceId(deviceId);
      _selectedAudioOutputDeviceId = normalizedDeviceId;

      if (normalizedDeviceId == null) {
        return const Ok<void>(null);
      }

      final outputDevicesResult = await listAudioOutputDevices();
      if (outputDevicesResult
          case Error<List<RuntimeAudioDevice>>(:final error)) {
        return Error<void>(error);
      }

      final outputDevices =
          (outputDevicesResult as Ok<List<RuntimeAudioDevice>>).value;
      final selectedOutputDevice = outputDevices
          .where((device) => device.id == normalizedDeviceId)
          .firstOrNull;
      if (selectedOutputDevice == null) {
        return Error<void>(
          Exception("Unknown audio output device id: $normalizedDeviceId"),
        );
      }

      final room = _activeRoom();
      if (room == null) {
        return const Ok<void>(null);
      }

      await room.setAudioOutputDevice(
        MediaDevice(
          selectedOutputDevice.id,
          selectedOutputDevice.label,
          "audiooutput",
          null,
        ),
      );

      return const Ok<void>(null);
    });
  }

  @override
  String? selectedAudioInputDeviceId() {
    final room = _activeRoom();
    return room?.selectedAudioInputDeviceId ?? _selectedAudioInputDeviceId;
  }

  @override
  String? selectedAudioOutputDeviceId() {
    final room = _activeRoom();
    return room?.selectedAudioOutputDeviceId ?? _selectedAudioOutputDeviceId;
  }

  @override
  Stream<void> audioDeviceChanges() {
    return _audioDeviceChangesController.stream;
  }

  void bindActiveRoom(Room? Function() activeRoom) {
    _activeRoom = activeRoom;
  }

  @override
  Future<Result<void>> applySelectedAudioDevicesToActiveRoom() async {
    try {
      final room = _activeRoom();
      if (room == null) {
        return const Ok<void>(null);
      }

      final selectedAudioInputDeviceId = _selectedAudioInputDeviceId;
      if (selectedAudioInputDeviceId != null) {
        final devices = await Hardware.instance.audioInputs();
        final selectedInputDevice = devices
            .where((device) => device.deviceId == selectedAudioInputDeviceId)
            .firstOrNull;
        if (selectedInputDevice != null) {
          await room.setAudioInputDevice(selectedInputDevice);
        }
      }

      final selectedAudioOutputDeviceId = _selectedAudioOutputDeviceId;
      if (selectedAudioOutputDeviceId != null) {
        final devices = await Hardware.instance.audioOutputs();
        final selectedOutputDevice = devices
            .where((device) => device.deviceId == selectedAudioOutputDeviceId)
            .firstOrNull;
        if (selectedOutputDevice != null) {
          await room.setAudioOutputDevice(selectedOutputDevice);
        }
      }

      return const Ok<void>(null);
    } on Exception catch (error) {
      return Error<void>(error);
    }
  }

  @override
  Future<void> close() async {
    await _deviceChangeSubscription.cancel();
    await _audioDeviceChangesController.close();
  }

  Future<Result<T>> _enqueue<T>(Future<Result<T>> Function() operation) {
    final completer = Completer<Result<T>>();
    _operationQueue = _operationQueue.then((_) async {
      try {
        final result = await operation();
        completer.complete(result);
      } on Exception catch (error) {
        completer.complete(Error<T>(error));
      }
    });

    return completer.future;
  }

  List<RuntimeAudioDevice> _toRuntimeAudioDevices({
    required Iterable<MediaDevice> devices,
    required String? systemDefaultDeviceId,
  }) {
    return devices
        .map(
          (device) => RuntimeAudioDevice(
            id: device.deviceId,
            label: device.label.trim().isEmpty ? device.deviceId : device.label,
            isSystemDefault: systemDefaultDeviceId == device.deviceId,
          ),
        )
        .toList(growable: false);
  }

  String? _resolveSystemDefaultDeviceId({
    required Iterable<MediaDevice> devices,
    required String kind,
  }) {
    final explicitDefaultDevice = devices.firstWhereOrNull(
      (device) => device.deviceId.trim().toLowerCase() == "default",
    );
    if (explicitDefaultDevice != null) {
      return explicitDefaultDevice.deviceId;
    }

    final selectedDevice = switch (kind) {
      "audioinput" => Hardware.instance.selectedAudioInput,
      "audiooutput" => Hardware.instance.selectedAudioOutput,
      _ => null,
    };
    if (selectedDevice == null) {
      return null;
    }

    final hasSelectedDevice =
        devices.any((device) => device.deviceId == selectedDevice.deviceId);
    if (!hasSelectedDevice) {
      return null;
    }

    return selectedDevice.deviceId;
  }

  String? _normalizeDeviceId(String? deviceId) {
    final trimmedDeviceId = deviceId?.trim();
    if (trimmedDeviceId == null || trimmedDeviceId.isEmpty) {
      return null;
    }

    return trimmedDeviceId;
  }

  static Room? _inactiveRoom() {
    return null;
  }
}
