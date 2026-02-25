import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
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

  Result<T> _missingTokenError<T>() {
    return Error<T>(Exception("Auth token is required."));
  }

  @override
  Future<Result<List<ApiMessage>>> listMessages({
    required String baseUrl,
    required String channelId,
  }) async {
    if (_authenticationStateSource.currentAuthState
        is! AuthenticationAuthenticatedState) {
      return _missingTokenError();
    }

    return _chatApi.listMessages(baseUrl: baseUrl, channelId: channelId);
  }

  @override
  Future<Result<ApiMessage>> createMessage({
    required String baseUrl,
    required String channelId,
    required String content,
  }) async {
    if (_authenticationStateSource.currentAuthState
        is! AuthenticationAuthenticatedState) {
      return _missingTokenError();
    }

    return _chatApi.createMessage(
      baseUrl: baseUrl,
      channelId: channelId,
      content: content,
    );
  }

  @override
  Future<Result<ApiMessage>> updateMessage({
    required String baseUrl,
    required String channelId,
    required String messageId,
    required String content,
  }) async {
    if (_authenticationStateSource.currentAuthState
        is! AuthenticationAuthenticatedState) {
      return _missingTokenError();
    }

    return _chatApi.updateMessage(
      baseUrl: baseUrl,
      channelId: channelId,
      messageId: messageId,
      content: content,
    );
  }

  @override
  Future<Result<void>> deleteMessage({
    required String baseUrl,
    required String channelId,
    required String messageId,
  }) async {
    if (_authenticationStateSource.currentAuthState
        is! AuthenticationAuthenticatedState) {
      return _missingTokenError();
    }

    return _chatApi.deleteMessage(
      baseUrl: baseUrl,
      channelId: channelId,
      messageId: messageId,
    );
  }
}
