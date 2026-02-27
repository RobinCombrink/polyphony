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
  });

  final String serverId;
  final String name;
}

abstract interface class ChannelRepo
    with
        RepositoryGetMany<Channel, GetChannelsQuery>,
        RepositoryCreateOne<Channel, CreateChannelCommand> {}
