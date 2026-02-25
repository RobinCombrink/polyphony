import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/domain_extensions/api_model_extensions.dart";
import "package:polyphony_flutter_client/shared/repositories/channel_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/channel_service.dart";

class ChannelRepository implements ChannelRepo {
  const ChannelRepository({required ChannelService channelService})
      : _channelService = channelService;

  final ChannelService _channelService;

  @override
  Future<Result<List<Channel>>> listChannels({
    required String baseUrl,
    required String serverId,
  }) async {
    final serviceResult = await _channelService.listChannels(
      baseUrl: baseUrl,
      serverId: serverId,
    );

    return switch (serviceResult) {
      Ok<List<ApiChannel>>(:final value) => Ok<List<Channel>>(
          value.map((channel) => channel.toDomainModel()).toList()),
      Error<List<ApiChannel>>(:final error) => Error<List<Channel>>(error),
    };
  }

  @override
  Future<Result<Channel>> createChannel({
    required String baseUrl,
    required String serverId,
    required String name,
  }) async {
    final serviceResult = await _channelService.createChannel(
      baseUrl: baseUrl,
      serverId: serverId,
      name: name,
    );

    return switch (serviceResult) {
      Ok<ApiChannel>(:final value) => Ok<Channel>(value.toDomainModel()),
      Error<ApiChannel>(:final error) => Error<Channel>(error),
    };
  }
}
