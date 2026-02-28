import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
import "package:polyphony_flutter_client/shared/config/polyphony_config.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/chat_api.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/server_service.dart";

class RestServerService implements ServerService {
  const RestServerService({
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
  Future<Result<List<ApiServer>>> listServers() async {
    if (_authenticationStateSource.currentAuthState
        is! AuthenticationAuthenticatedState) {
      return _missingTokenError();
    }

    return _chatApi.listServers(baseUrl: _baseUrl);
  }

  @override
  Future<Result<ApiServer>> createServer({
    required String name,
  }) async {
    if (_authenticationStateSource.currentAuthState
        is! AuthenticationAuthenticatedState) {
      return _missingTokenError();
    }

    return _chatApi.createServer(baseUrl: _baseUrl, name: name);
  }

  @override
  Future<Result<void>> deleteServer({
    required String serverId,
  }) async {
    if (_authenticationStateSource.currentAuthState
        is! AuthenticationAuthenticatedState) {
      return _missingTokenError();
    }

    return _chatApi.deleteServer(
      baseUrl: _baseUrl,
      serverId: serverId,
    );
  }

  @override
  Future<Result<void>> addServerMember({
    required String serverId,
    required String userId,
  }) async {
    if (_authenticationStateSource.currentAuthState
        is! AuthenticationAuthenticatedState) {
      return _missingTokenError();
    }

    return _chatApi.addServerMember(
      baseUrl: _baseUrl,
      serverId: serverId,
      userId: userId,
    );
  }

  @override
  Future<Result<List<ApiServerMember>>> listServerMembers({
    required String serverId,
  }) async {
    if (_authenticationStateSource.currentAuthState
        is! AuthenticationAuthenticatedState) {
      return _missingTokenError();
    }

    return _chatApi.listServerMembers(
      baseUrl: _baseUrl,
      serverId: serverId,
    );
  }
}
