import "dart:async";

import "package:polyphony_flutter_client/shared/result/result.dart";

enum RuntimeAudioChannel {
  voice,
  livestream,
}

final class RuntimeAudioDevice {
  const RuntimeAudioDevice({
    required this.id,
    required this.label,
    this.isSystemDefault = false,
  });

  final String id;
  final String label;
  final bool isSystemDefault;
}

sealed class ParticipantStatusUpdate {
  const ParticipantStatusUpdate({
    required this.participantUserId,
  });

  final String participantUserId;
}

final class ParticipantSpeakingStatusUpdated extends ParticipantStatusUpdate {
  const ParticipantSpeakingStatusUpdated({
    required super.participantUserId,
    required this.isSpeaking,
  });

  final bool isSpeaking;
}

final class ParticipantMutedStatusUpdated extends ParticipantStatusUpdate {
  const ParticipantMutedStatusUpdated({
    required super.participantUserId,
    required this.isMuted,
  });

  final bool isMuted;
}

final class ParticipantDeafenedStatusUpdated extends ParticipantStatusUpdate {
  const ParticipantDeafenedStatusUpdated({
    required super.participantUserId,
    required this.isDeafened,
  });

  final bool isDeafened;
}

abstract interface class MediaRuntimeService {
  Future<void> close();

  Future<Result<void>> connect({
    required String livekitUrl,
    required String accessToken,
  });

  Future<Result<void>> disconnect();

  Future<Result<void>> setSelfMuted({required bool muted});

  Future<Result<void>> setSelfDeafened({required bool deafened});

  Future<Result<void>> setSelfScreenShareEnabled({
    required bool enabled,
    String? sourceId,
  });

  Future<Result<void>> setAudioChannelEnabled({
    required RuntimeAudioChannel channel,
    required bool enabled,
  });

  Future<Result<void>> setParticipantAudioChannel({
    required String participantUserId,
    required RuntimeAudioChannel channel,
  });

  Future<Result<List<RuntimeAudioDevice>>> listAudioInputDevices();

  Future<Result<List<RuntimeAudioDevice>>> listAudioOutputDevices();

  Future<Result<void>> setSelectedAudioInputDeviceId(String? deviceId);

  Future<Result<void>> setSelectedAudioOutputDeviceId(String? deviceId);

  String? selectedAudioInputDeviceId();

  String? selectedAudioOutputDeviceId();

  Stream<void> audioDeviceChanges();

  bool isSelfMuted();

  bool isSelfDeafened();

  bool isSelfScreenShareEnabled();

  bool isAudioChannelEnabled(RuntimeAudioChannel channel);

  RuntimeAudioChannel participantAudioChannel(String participantUserId);

  Iterable<String> currentParticipantUserIds();

  Set<String> currentMutedParticipantUserIds();

  Set<String> currentDeafenedParticipantUserIds();

  Stream<Set<String>> participantUserIds();

  Stream<ParticipantStatusUpdate> participantStatusUpdates();

  Map<String, Object> currentParticipantVideoTracks();

  Stream<Map<String, Object>> participantVideoTracks();
}
