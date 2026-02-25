import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/chat_api.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/voice_session_service.dart";

class RestVoiceSessionService implements VoiceSessionService {
  const RestVoiceSessionService({
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
  Future<Result<List<ApiVoiceSession>>> listVoiceSessions({
    required String baseUrl,
    required String channelId,
  }) async {
    if (_authenticationStateSource.currentAuthState
        is! AuthenticationAuthenticatedState) {
      return _missingTokenError();
    }

    return _chatApi.listVoiceSessions(
      baseUrl: baseUrl,
      channelId: channelId,
    );
  }

  @override
  Future<Result<ApiVoiceSession>> joinVoiceSession({
    required String baseUrl,
    required String channelId,
  }) async {
    if (_authenticationStateSource.currentAuthState
        is! AuthenticationAuthenticatedState) {
      return _missingTokenError();
    }

    return _chatApi.joinVoiceSession(
      baseUrl: baseUrl,
      channelId: channelId,
    );
  }

  @override
  Future<Result<void>> leaveVoiceSession({
    required String baseUrl,
    required String channelId,
  }) async {
    if (_authenticationStateSource.currentAuthState
        is! AuthenticationAuthenticatedState) {
      return _missingTokenError();
    }

    return _chatApi.leaveVoiceSession(
      baseUrl: baseUrl,
      channelId: channelId,
    );
  }
}
