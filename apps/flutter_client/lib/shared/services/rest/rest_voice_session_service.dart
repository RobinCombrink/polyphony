import "package:polyphony_flutter_client/shared/config/polyphony_config.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/chat_api.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/voice_session_service.dart";

final class RestVoiceSessionService implements VoiceSessionService {
  RestVoiceSessionService({
    required ChatApi chatApi,
  }) : _chatApi = chatApi;

  final ChatApi _chatApi;
  final String _baseUrl = PolyphonyConfig.backendBaseUrl;

  @override
  Future<Result<ApiVoiceConnectSession>> connectVoiceSession({
    required String channelId,
    String? participantInstanceId,
  }) {
    return _chatApi.connectVoiceSession(
      baseUrl: _baseUrl,
      channelId: channelId,
      participantInstanceId: participantInstanceId,
    );
  }
}
