import "package:polyphony_flutter_client/shared/config/backend_base_url_resolver.dart";
import "package:polyphony_flutter_client/shared/models/channel_type.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/chat_api.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/channel_service.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";

class RestChannelService implements ChannelService {
  RestChannelService({
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
  Future<Result<List<ApiChannel>>> listChannels({
    required String serverId,
  }) async {
    return _chatApi.listChannels(
      baseUrl: await _baseUrl(),
      serverId: serverId,
    );
  }

  @override
  Future<Result<ApiChannel>> createChannel({
    required String serverId,
    required String name,
    required ChannelType channelType,
  }) async {
    return _chatApi.createChannel(
      baseUrl: await _baseUrl(),
      serverId: serverId,
      name: name,
      channelType: channelType,
    );
  }

  @override
  Future<Result<void>> deleteChannel({
    required String channelId,
  }) async {
    return _chatApi.deleteChannel(
      baseUrl: await _baseUrl(),
      channelId: channelId,
    );
  }
}
