import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

abstract interface class VoiceSessionService {
  Future<Result<List<ApiVoiceSession>>> listVoiceSessions({
    required String channelId,
  });

  Future<Result<void>> setSelfMuted({
    required String channelId,
    required bool isMuted,
  });

  Future<Result<ApiVoiceConnectSession>> connectVoiceSession({
    required String channelId,
  });

  Future<Result<void>> disconnectVoiceSession({
    required String channelId,
  });
}
