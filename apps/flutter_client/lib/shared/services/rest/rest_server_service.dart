import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
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

  Result<T> _missingTokenError<T>() {
    return Error<T>(Exception("Auth token is required."));
  }

  @override
  Future<Result<List<ApiServer>>> listServers({
    required String baseUrl,
  }) async {
    if (_authenticationStateSource.currentAuthState
        is! AuthenticationAuthenticatedState) {
      return _missingTokenError();
    }

    return _chatApi.listServers(baseUrl: baseUrl);
  }

  @override
  Future<Result<ApiServer>> createServer({
    required String baseUrl,
    required String name,
  }) async {
    if (_authenticationStateSource.currentAuthState
        is! AuthenticationAuthenticatedState) {
      return _missingTokenError();
    }

    return _chatApi.createServer(baseUrl: baseUrl, name: name);
  }
}
