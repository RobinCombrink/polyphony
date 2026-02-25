import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

abstract interface class VoiceSessionRepo {
  Future<Result<List<VoiceSession>>> listVoiceSessions({
    required String baseUrl,
    required String channelId,
  });

  Future<Result<VoiceSession>> joinVoiceSession({
    required String baseUrl,
    required String channelId,
  });

  Future<Result<void>> leaveVoiceSession({
    required String baseUrl,
    required String channelId,
  });
}
