import "package:polyphony_flutter_client/shared/config/backend_base_url_resolver.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/chat_api.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";
import "package:polyphony_flutter_client/shared/services/voice_session_service.dart";

final class RestVoiceSessionService implements VoiceSessionService {
  RestVoiceSessionService({
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
  Future<Result<ApiVoiceConnectSession>> connectVoiceSession({
    required String channelId,
    String? participantInstanceId,
  }) async {
    return _chatApi.connectVoiceSession(
      baseUrl: await _baseUrl(),
      channelId: channelId,
      participantInstanceId: participantInstanceId,
    );
  }
}
