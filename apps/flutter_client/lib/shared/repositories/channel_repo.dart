import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

abstract interface class ChannelRepo {
  Future<Result<List<Channel>>> listChannels({
    required String baseUrl,
    required String serverId,
  });

  Future<Result<Channel>> createChannel({
    required String baseUrl,
    required String serverId,
    required String name,
  });
}
