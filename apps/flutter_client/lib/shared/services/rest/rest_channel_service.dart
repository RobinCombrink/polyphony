import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/chat_api.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/channel_service.dart";

class RestChannelService implements ChannelService {
  const RestChannelService({
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
  Future<Result<List<ApiChannel>>> listChannels({
    required String baseUrl,
    required String serverId,
  }) async {
    if (_authenticationStateSource.currentAuthState
        is! AuthenticationAuthenticatedState) {
      return _missingTokenError();
    }

    return _chatApi.listChannels(baseUrl: baseUrl, serverId: serverId);
  }

  @override
  Future<Result<ApiChannel>> createChannel({
    required String baseUrl,
    required String serverId,
    required String name,
  }) async {
    if (_authenticationStateSource.currentAuthState
        is! AuthenticationAuthenticatedState) {
      return _missingTokenError();
    }

    return _chatApi.createChannel(
      baseUrl: baseUrl,
      serverId: serverId,
      name: name,
    );
  }
}
