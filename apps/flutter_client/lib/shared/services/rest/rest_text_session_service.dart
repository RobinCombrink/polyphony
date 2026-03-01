import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/chat_api.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/rest/authenticated_rest_session_service_base.dart";
import "package:polyphony_flutter_client/shared/services/text_session_service.dart";

final class RestTextSessionService extends AuthenticatedRestSessionServiceBase
    implements TextSessionService {
  RestTextSessionService({
    required ChatApi chatApi,
    required super.authenticationStateSource,
  }) : _chatApi = chatApi;

  final ChatApi _chatApi;

  @override
  Future<Result<ApiTextConnectSession>> connectTextSession({
    required String channelId,
  }) {
    return executeAuthenticated(
      (baseUrl) => _chatApi.connectTextSession(
        baseUrl: baseUrl,
        channelId: channelId,
      ),
    );
  }
}
