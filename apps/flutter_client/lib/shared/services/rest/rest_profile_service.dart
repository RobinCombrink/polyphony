import "package:polyphony_flutter_client/shared/config/backend_base_url_resolver.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/chat_api.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";
import "package:polyphony_flutter_client/shared/services/profile_service.dart";

class RestProfileService implements ProfileService {
  RestProfileService({
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
  Future<Result<ApiMe>> getMe() async {
    return _chatApi.getMe(baseUrl: await _baseUrl());
  }

  @override
  Future<Result<ApiMe>> updateDisplayName({
    required String displayName,
  }) async {
    return _chatApi.updateDisplayName(
      baseUrl: await _baseUrl(),
      displayName: displayName,
    );
  }

  @override
  Future<Result<ApiUserLookup>> getUserById({
    required String userId,
  }) async {
    return _chatApi.getUserById(
      baseUrl: await _baseUrl(),
      userId: userId,
    );
  }
}
