import "dart:async";

import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/media_runtime_service.dart";

abstract interface class AudioDeviceRuntimeService {
  Future<Result<List<RuntimeAudioDevice>>> listAudioInputDevices();

  Future<Result<List<RuntimeAudioDevice>>> listAudioOutputDevices();

  Future<Result<void>> setSelectedAudioInputDeviceId(String? deviceId);

  Future<Result<void>> setSelectedAudioOutputDeviceId(String? deviceId);

  String? selectedAudioInputDeviceId();

  String? selectedAudioOutputDeviceId();

  Stream<void> audioDeviceChanges();

  Future<Result<void>> applySelectedAudioDevicesToActiveRoom();

  Future<void> close();
}
