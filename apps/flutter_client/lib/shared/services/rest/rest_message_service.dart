import "package:polyphony_flutter_client/shared/config/polyphony_config.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/chat_api.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/message_service.dart";

class RestMessageService implements MessageService {
  const RestMessageService({
    required ChatApi chatApi,
  }) : _chatApi = chatApi;

  final ChatApi _chatApi;
  final String _baseUrl = PolyphonyConfig.backendBaseUrl;

  @override
  Future<Result<List<ApiMessage>>> listMessages({
    required String channelId,
  }) {
    return _chatApi.listMessages(baseUrl: _baseUrl, channelId: channelId);
  }

  @override
  Future<Result<ApiMessage>> createMessage({
    required String channelId,
    required String content,
    String? mentionedUserId,
  }) {
    return _chatApi.createMessage(
      baseUrl: _baseUrl,
      channelId: channelId,
      content: content,
      mentionedUserId: mentionedUserId,
    );
  }

  @override
  Future<Result<ApiMessage>> updateMessage({
    required String channelId,
    required String messageId,
    required String content,
  }) {
    return _chatApi.updateMessage(
      baseUrl: _baseUrl,
      channelId: channelId,
      messageId: messageId,
      content: content,
    );
  }

  @override
  Future<Result<void>> deleteMessage({
    required String channelId,
    required String messageId,
  }) {
    return _chatApi.deleteMessage(
      baseUrl: _baseUrl,
      channelId: channelId,
      messageId: messageId,
    );
  }
}
