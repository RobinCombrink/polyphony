import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/chat_api.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/rest/authenticated_rest_session_service_base.dart";
import "package:polyphony_flutter_client/shared/services/voice_session_service.dart";

final class RestVoiceSessionService extends AuthenticatedRestSessionServiceBase
    implements VoiceSessionService {
  RestVoiceSessionService({
    required ChatApi chatApi,
    required super.authenticationStateSource,
  }) : _chatApi = chatApi;

  final ChatApi _chatApi;

  @override
  Future<Result<ApiVoiceConnectSession>> connectVoiceSession({
    required String channelId,
    String? participantInstanceId,
  }) {
    return executeAuthenticated(
      (baseUrl) => _chatApi.connectVoiceSession(
        baseUrl: baseUrl,
        channelId: channelId,
        participantInstanceId: participantInstanceId,
      ),
    );
  }
}
