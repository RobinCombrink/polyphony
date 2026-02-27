import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
import "package:polyphony_flutter_client/shared/config/polyphony_config.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/chat_api.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/message_service.dart";

class RestMessageService implements MessageService {
  const RestMessageService({
    required ChatApi chatApi,
    required AuthenticationStateSource authenticationStateSource,
  })  : _chatApi = chatApi,
        _authenticationStateSource = authenticationStateSource;

  final ChatApi _chatApi;
  final AuthenticationStateSource _authenticationStateSource;
  final String _baseUrl = PolyphonyConfig.backendBaseUrl;

  Result<T> _missingTokenError<T>() {
    return Error<T>(Exception("Auth token is required."));
  }

  @override
  Future<Result<List<ApiMessage>>> listMessages({
    required String channelId,
  }) async {
    if (_authenticationStateSource.currentAuthState
        is! AuthenticationAuthenticatedState) {
      return _missingTokenError();
    }

    return _chatApi.listMessages(baseUrl: _baseUrl, channelId: channelId);
  }

  @override
  Future<Result<ApiMessage>> createMessage({
    required String channelId,
    required String content,
  }) async {
    if (_authenticationStateSource.currentAuthState
        is! AuthenticationAuthenticatedState) {
      return _missingTokenError();
    }

    return _chatApi.createMessage(
      baseUrl: _baseUrl,
      channelId: channelId,
      content: content,
    );
  }

  @override
  Future<Result<ApiMessage>> updateMessage({
    required String channelId,
    required String messageId,
    required String content,
  }) async {
    if (_authenticationStateSource.currentAuthState
        is! AuthenticationAuthenticatedState) {
      return _missingTokenError();
    }

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
  }) async {
    if (_authenticationStateSource.currentAuthState
        is! AuthenticationAuthenticatedState) {
      return _missingTokenError();
    }

    return _chatApi.deleteMessage(
      baseUrl: _baseUrl,
      channelId: channelId,
      messageId: messageId,
    );
  }
}
