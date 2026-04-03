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
  Future<Result<Iterable<Channel>>> getMany({
    required GetChannelsQuery query,
  }) async {
    final serviceResult = await _channelService.listChannels(
      serverId: query.serverId.value,
    );

    return switch (serviceResult) {
      Ok<List<ApiChannel>>(:final value) => Ok<Iterable<Channel>>(
          value.map((channel) => channel.toDomainModel()).toList()),
      Error<List<ApiChannel>>(:final error) => Error<Iterable<Channel>>(error),
    };
  }

  @override
  Future<Result<Channel>> createOne({
    required CreateChannelCommand command,
  }) async {
    final serviceResult = await _channelService.createChannel(
      serverId: command.serverId.value,
      name: command.name,
      channelType: command.channelType,
    );

    return switch (serviceResult) {
      Ok<ApiChannel>(:final value) => Ok<Channel>(value.toDomainModel()),
      Error<ApiChannel>(:final error) => Error<Channel>(error),
    };
  }

  @override
  Future<Result<void>> deleteOne({required DeleteChannelCommand command}) {
    return _channelService.deleteChannel(
      channelId: command.channelId.value,
    );
  }

  @override
  Future<Result<void>> updateOne({required UpdateChannelNameCommand command}) {
    return _channelService.updateChannelName(
      channelId: command.channelId.value,
      name: command.name,
    );
  }
}
