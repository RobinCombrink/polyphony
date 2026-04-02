import "package:polyphony_flutter_client/shared/models/channel_type.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

abstract interface class ChannelService {
  Future<Result<List<ApiChannel>>> listChannels({
    required String serverId,
  });

  Future<Result<ApiChannel>> createChannel({
    required String serverId,
    required String name,
    required ChannelType channelType,
  });

  Future<Result<void>> deleteChannel({
    required String channelId,
  });

  Future<Result<void>> updateChannelName({
    required String channelId,
    required String name,
  });
}
