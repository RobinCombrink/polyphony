import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_request_service_base.dart";
import "package:polyphony_flutter_client/shared/services/text_session_service.dart";

final class RestTextSessionService extends RestRequestServiceBase
    implements TextSessionService {
  RestTextSessionService({
    required super.dio,
  });

  @override
  Future<Result<ApiTextConnectSession>> connectTextSession({
    required String channelId,
  }) {
    return performPostRequest<ApiTextConnectSession>(
      endpoint: "/api/v1/channels/$channelId/session",
      operation: "connect text session",
      body: const <String, dynamic>{"session_type": "text"},
      expectedStatusCode: 200,
      decodeItem: ApiTextConnectSession.fromJson,
    );
  }
}
