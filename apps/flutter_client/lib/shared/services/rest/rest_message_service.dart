import "package:polyphony_flutter_client/shared/config/backend_base_url_resolver.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/chat_api.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/message_service.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";

class RestMessageService implements MessageService {
  RestMessageService({
    required ChatApi chatApi,
    required PreferencesStore preferencesStore,
  })  : _chatApi = chatApi,
        _preferencesStore = preferencesStore;

  final ChatApi _chatApi;
  final PreferencesStore _preferencesStore;

  Future<String> _baseUrl() {
    return resolveBackendBaseUrl(preferencesStore: _preferencesStore);
  }

  @override
  Future<Result<List<ApiMessage>>> listMessages({
    required String channelId,
  }) async {
    return _chatApi.listMessages(
      baseUrl: await _baseUrl(),
      channelId: channelId,
    );
  }

  @override
  Future<Result<ApiMessage>> createMessage({
    required String channelId,
    required String content,
    String? mentionedUserId,
  }) async {
    return _chatApi.createMessage(
      baseUrl: await _baseUrl(),
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
  }) async {
    return _chatApi.updateMessage(
      baseUrl: await _baseUrl(),
      channelId: channelId,
      messageId: messageId,
      content: content,
    );
  }

  @override
  Future<Result<void>> deleteMessage({
    required String channelId,
    required String messageId,
  }) async {
    return _chatApi.deleteMessage(
      baseUrl: await _baseUrl(),
      channelId: channelId,
      messageId: messageId,
    );
  }
}
