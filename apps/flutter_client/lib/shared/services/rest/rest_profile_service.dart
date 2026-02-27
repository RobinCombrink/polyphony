import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
import "package:polyphony_flutter_client/shared/config/polyphony_config.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/chat_api.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/profile_service.dart";

class RestProfileService implements ProfileService {
  const RestProfileService({
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
  Future<Result<ApiMe>> getMe() async {
    if (_authenticationStateSource.currentAuthState
        is! AuthenticationAuthenticatedState) {
      return _missingTokenError();
    }

    return _chatApi.getMe(baseUrl: _baseUrl);
  }

  @override
  Future<Result<ApiMe>> updateDisplayName({
    required String displayName,
  }) async {
    if (_authenticationStateSource.currentAuthState
        is! AuthenticationAuthenticatedState) {
      return _missingTokenError();
    }

    return _chatApi.updateDisplayName(
      baseUrl: _baseUrl,
      displayName: displayName,
    );
  }
}
