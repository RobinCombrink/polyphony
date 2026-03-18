import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/direct_message_service.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_request_service_base.dart";

class RestDirectMessageService extends RestRequestServiceBase
    implements DirectMessageService {
  RestDirectMessageService({
    required super.dio,
  });

  @override
  Future<Result<List<ApiDirectMessage>>> listMessages(
      {required String threadId}) {
    return performListRequest<ApiDirectMessage>(
      endpoint: "/api/v1/dms/threads/$threadId/messages",
      operation: "list direct messages",
      decodeItem: ApiDirectMessage.fromJson,
    );
  }

  @override
  Future<Result<List<ApiDirectMessageThread>>> listThreads() {
    return performListRequest<ApiDirectMessageThread>(
      endpoint: "/api/v1/dms/threads",
      operation: "list direct message threads",
      decodeItem: ApiDirectMessageThread.fromJson,
    );
  }

  @override
  Future<Result<ApiDirectMessageThread>> openOrGetThread(
      {required String userId}) {
    return performPostRequest<ApiDirectMessageThread>(
      endpoint: "/api/v1/dms/threads/$userId",
      operation: "open or get direct message thread",
      body: const <String, dynamic>{},
      expectedStatusCode: 201,
      decodeItem: ApiDirectMessageThread.fromJson,
    );
  }

  @override
  Future<Result<List<ApiDirectMessage>>> searchMessagesForUser({
    required String userId,
    required String query,
  }) {
    return performListRequest<ApiDirectMessage>(
      endpoint:
          "/api/v1/dms/search/$userId?q=${Uri.encodeQueryComponent(query)}",
      operation: "search direct messages",
      decodeItem: ApiDirectMessage.fromJson,
    );
  }

  @override
  Future<Result<ApiDirectMessage>> sendMessage({
    required String threadId,
    required String content,
  }) {
    return performPostRequest<ApiDirectMessage>(
      endpoint: "/api/v1/dms/threads/$threadId/messages",
      operation: "send direct message",
      body: <String, dynamic>{"content": content},
      expectedStatusCode: 201,
      decodeItem: ApiDirectMessage.fromJson,
    );
  }
}
