import "package:polyphony_flutter_client/shared/config/backend_base_url_resolver.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/chat_api.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";
import "package:polyphony_flutter_client/shared/services/server_service.dart";

class RestServerService implements ServerService {
  RestServerService({
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
  Future<Result<List<ApiServer>>> listServers() async {
    return _chatApi.listServers(baseUrl: await _baseUrl());
  }

  @override
  Future<Result<ApiServer>> createServer({
    required String name,
  }) async {
    return _chatApi.createServer(baseUrl: await _baseUrl(), name: name);
  }

  @override
  Future<Result<void>> deleteServer({
    required String serverId,
  }) async {
    return _chatApi.deleteServer(
      baseUrl: await _baseUrl(),
      serverId: serverId,
    );
  }

  @override
  Future<Result<void>> addServerMember({
    required String serverId,
    required String userId,
  }) async {
    return _chatApi.addServerMember(
      baseUrl: await _baseUrl(),
      serverId: serverId,
      userId: userId,
    );
  }

  @override
  Future<Result<List<ApiServerMember>>> listServerMembers({
    required String serverId,
  }) async {
    return _chatApi.listServerMembers(
      baseUrl: await _baseUrl(),
      serverId: serverId,
    );
  }
}
