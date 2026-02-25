import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

abstract interface class VoiceSessionService {
  Future<Result<List<ApiVoiceSession>>> listVoiceSessions({
    required String baseUrl,
    required String channelId,
  });

  Future<Result<ApiVoiceSession>> joinVoiceSession({
    required String baseUrl,
    required String channelId,
  });

  Future<Result<void>> leaveVoiceSession({
    required String baseUrl,
    required String channelId,
  });
}
