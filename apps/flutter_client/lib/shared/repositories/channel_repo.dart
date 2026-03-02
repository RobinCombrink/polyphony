import "package:polyphony_flutter_client/shared/models/channel_type.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/repositories/repository_mixins.dart";

class GetChannelsQuery {
  const GetChannelsQuery({
    required this.serverId,
  });

  final String serverId;
}

class CreateChannelCommand {
  const CreateChannelCommand({
    required this.serverId,
    required this.name,
    required this.channelType,
  });

  final String serverId;
  final String name;
  final ChannelType channelType;
}

class DeleteChannelCommand {
  const DeleteChannelCommand({
    required this.channelId,
  });

  final String channelId;
}

abstract interface class ChannelRepo
    with
        RepositoryGetMany<Channel, GetChannelsQuery>,
        RepositoryCreateOne<Channel, CreateChannelCommand>,
        RepositoryDeleteOne<DeleteChannelCommand> {}
