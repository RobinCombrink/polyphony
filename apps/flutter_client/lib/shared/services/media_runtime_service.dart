import "dart:async";

import "package:polyphony_flutter_client/shared/result/result.dart";

enum RuntimeAudioChannel {
  voice,
  livestream,
}

abstract interface class MediaRuntimeService {
  Future<Result<void>> connect({
    required String livekitUrl,
    required String accessToken,
  });

  Future<Result<void>> disconnect();

  Future<Result<void>> setSelfMuted({required bool muted});

  Future<Result<void>> setSelfDeafened({required bool deafened});

  Future<Result<void>> setSelfVideoEnabled({required bool enabled});

  Future<Result<void>> setAudioChannelEnabled({
    required RuntimeAudioChannel channel,
    required bool enabled,
  });

  Future<Result<void>> setParticipantAudioChannel({
    required String participantUserId,
    required RuntimeAudioChannel channel,
  });

  bool isSelfMuted();

  bool isSelfDeafened();

  bool isSelfVideoEnabled();

  bool isAudioChannelEnabled(RuntimeAudioChannel channel);

  RuntimeAudioChannel participantAudioChannel(String participantUserId);

  Iterable<String> currentParticipantUserIds();

  Stream<Set<String>> participantUserIds();

  Stream<Set<String>> speakingParticipantUserIds();

  Map<String, Object> currentParticipantVideoTracks();

  Stream<Map<String, Object>> participantVideoTracks();
}
