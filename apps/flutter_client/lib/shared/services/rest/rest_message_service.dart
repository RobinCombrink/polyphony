import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/message_service.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_request_service_base.dart";

class RestMessageService extends RestRequestServiceBase
    implements MessageService {
  RestMessageService({
    required super.dio,
  });

  @override
  Future<Result<List<ApiMessage>>> listMessages({
    required String channelId,
  }) {
    return performListRequest<ApiMessage>(
      endpoint: "/api/v1/channels/$channelId/messages",
      operation: "list messages",
      decodeItem: ApiMessage.fromJson,
    );
  }

  @override
  Future<Result<ApiMessage>> createMessage({
    required String channelId,
    required String content,
    String? mentionedUserId,
  }) {
    final trimmedMentionedUserId = mentionedUserId?.trim();

    return performPostRequest<ApiMessage>(
      endpoint: "/api/v1/channels/$channelId/messages",
      operation: "create message",
      body: <String, dynamic>{
        "content": content,
        if (trimmedMentionedUserId != null && trimmedMentionedUserId.isNotEmpty)
          "mentioned_user_id": trimmedMentionedUserId,
      },
      expectedStatusCode: 201,
      decodeItem: ApiMessage.fromJson,
    );
  }

  @override
  Future<Result<ApiMessage>> updateMessage({
    required String channelId,
    required String messageId,
    required String content,
  }) {
    return performPatchRequest<ApiMessage>(
      endpoint: "/api/v1/channels/$channelId/messages/$messageId",
      operation: "update message",
      body: <String, dynamic>{"content": content},
      expectedStatusCode: 200,
      decodeItem: ApiMessage.fromJson,
    );
  }

  @override
  Future<Result<void>> deleteMessage({
    required String channelId,
    required String messageId,
  }) {
    return performDeleteRequest(
      endpoint: "/api/v1/channels/$channelId/messages/$messageId",
      operation: "delete message",
      expectedStatusCode: 204,
    );
  }

  @override
  Future<Result<List<ApiMessage>>> searchMessages({
    required String channelId,
    required String query,
  }) {
    final encodedQuery = Uri.encodeQueryComponent(query);
    return performListRequest<ApiMessage>(
      endpoint: "/api/v1/channels/$channelId/messages/search?q=$encodedQuery",
      operation: "search messages",
      decodeItem: ApiMessage.fromJson,
    );
  }
}
