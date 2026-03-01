import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
import "package:polyphony_flutter_client/shared/config/polyphony_config.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/chat_api.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/channel_service.dart";
import "package:polyphony_flutter_client/shared/models/channel_type.dart";

class RestChannelService implements ChannelService {
  const RestChannelService({
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
  Future<Result<List<ApiChannel>>> listChannels({
    required String serverId,
  }) async {
    if (_authenticationStateSource.currentAuthState
        is! AuthenticationAuthenticatedState) {
      return _missingTokenError();
    }

    return _chatApi.listChannels(baseUrl: _baseUrl, serverId: serverId);
  }

  @override
  Future<Result<ApiChannel>> createChannel({
    required String serverId,
    required String name,
    required ChannelType channelType,
  }) async {
    if (_authenticationStateSource.currentAuthState
        is! AuthenticationAuthenticatedState) {
      return _missingTokenError();
    }

    return _chatApi.createChannel(
      baseUrl: _baseUrl,
      serverId: serverId,
      name: name,
      channelType: channelType,
    );
  }

  @override
  Future<Result<void>> deleteChannel({
    required String channelId,
  }) async {
    if (_authenticationStateSource.currentAuthState
        is! AuthenticationAuthenticatedState) {
      return _missingTokenError();
    }

    return _chatApi.deleteChannel(
      baseUrl: _baseUrl,
      channelId: channelId,
    );
  }
}
