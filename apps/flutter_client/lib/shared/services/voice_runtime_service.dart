import "package:polyphony_flutter_client/shared/result/result.dart";

abstract interface class VoiceRuntimeService {
  Future<Result<void>> connect({
    required String livekitUrl,
    required String accessToken,
  });

  Future<Result<void>> disconnect();

  Future<Result<void>> setSelfMuted({required bool muted});

  Future<Result<void>> setSelfDeafened({required bool deafened});

  bool isSelfMuted();

  bool isSelfDeafened();

  Iterable<String> currentParticipantUserIds();
}
