import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

abstract interface class VoiceSessionRepo {
  Future<Result<VoiceConnectSession>> connectVoiceSession({
    required String baseUrl,
    required String channelId,
  });

  Future<Result<void>> disconnectVoiceSession({
    required String baseUrl,
    required String channelId,
  });
}
