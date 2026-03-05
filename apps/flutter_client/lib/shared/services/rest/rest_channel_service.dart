import "package:polyphony_flutter_client/shared/config/polyphony_config.dart";
import "package:polyphony_flutter_client/shared/models/channel_type.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/chat_api.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/channel_service.dart";

class RestChannelService implements ChannelService {
  const RestChannelService({
    required ChatApi chatApi,
  }) : _chatApi = chatApi;

  final ChatApi _chatApi;
  final String _baseUrl = PolyphonyConfig.backendBaseUrl;

  @override
  Future<Result<List<ApiChannel>>> listChannels({
    required String serverId,
  }) {
    return _chatApi.listChannels(baseUrl: _baseUrl, serverId: serverId);
  }

  @override
  Future<Result<ApiChannel>> createChannel({
    required String serverId,
    required String name,
    required ChannelType channelType,
  }) {
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
  }) {
    return _chatApi.deleteChannel(
      baseUrl: _baseUrl,
      channelId: channelId,
    );
  }
}
