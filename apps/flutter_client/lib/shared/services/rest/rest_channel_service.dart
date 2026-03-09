import "package:polyphony_flutter_client/shared/models/channel_type.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/channel_service.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_request_service_base.dart";

class RestChannelService extends RestRequestServiceBase
    implements ChannelService {
  RestChannelService({
    required super.dio,
  });

  @override
  Future<Result<List<ApiChannel>>> listChannels({
    required String serverId,
  }) {
    return performListRequest<ApiChannel>(
      endpoint: "/api/v1/servers/$serverId/channels",
      operation: "list channels",
      decodeItem: ApiChannel.fromJson,
    );
  }

  @override
  Future<Result<ApiChannel>> createChannel({
    required String serverId,
    required String name,
    required ChannelType channelType,
  }) {
    return performPostRequest<ApiChannel>(
      endpoint: "/api/v1/servers/$serverId/channels",
      operation: "create channel",
      body: <String, dynamic>{
        "name": name,
        "channel_type": channelType.apiValue,
      },
      expectedStatusCode: 201,
      decodeItem: ApiChannel.fromJson,
    );
  }

  @override
  Future<Result<void>> deleteChannel({
    required String channelId,
  }) {
    return performDeleteRequest(
      endpoint: "/api/v1/channels/$channelId",
      operation: "delete channel",
      expectedStatusCode: 204,
    );
  }
}
