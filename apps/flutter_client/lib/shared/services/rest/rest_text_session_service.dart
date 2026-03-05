import "package:polyphony_flutter_client/shared/config/polyphony_config.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/chat_api.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/text_session_service.dart";

final class RestTextSessionService implements TextSessionService {
  RestTextSessionService({
    required ChatApi chatApi,
  }) : _chatApi = chatApi;

  final ChatApi _chatApi;
  final String _baseUrl = PolyphonyConfig.backendBaseUrl;

  @override
  Future<Result<ApiTextConnectSession>> connectTextSession({
    required String channelId,
  }) {
    return _chatApi.connectTextSession(
      baseUrl: _baseUrl,
      channelId: channelId,
    );
  }
}
