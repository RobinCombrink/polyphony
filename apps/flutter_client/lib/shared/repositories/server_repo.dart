import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/repositories/repository_mixins.dart";

class GetServersQuery {
  const GetServersQuery();
}

class CreateServerCommand {
  const CreateServerCommand({
    required this.name,
  });

  final String name;
}

class DeleteServerCommand {
  const DeleteServerCommand({
    required this.serverId,
  });

  final ServerId serverId;
}

sealed class ServerUpdateCommand {
  const ServerUpdateCommand();
}

class UpdateServerNameCommand extends ServerUpdateCommand {
  const UpdateServerNameCommand({
    required this.serverId,
    required this.name,
  }) : super();

  final ServerId serverId;
  final String name;
}

class InviteFriendToServerCommand extends ServerUpdateCommand {
  const InviteFriendToServerCommand({
    required this.serverId,
    required this.friendUserId,
  }) : super();

  final ServerId serverId;
  final UserId friendUserId;
}

class AddServerMemberUpdateCommand extends ServerUpdateCommand {
  const AddServerMemberUpdateCommand({
    required this.serverId,
    required this.userId,
  }) : super();

  final ServerId serverId;
  final UserId userId;
}

abstract interface class ServerRepo
    with
        RepositoryGetMany<Server, GetServersQuery>,
        RepositoryCreateOne<Server, CreateServerCommand>,
        RepositoryDeleteOne<DeleteServerCommand>,
        RepositoryUpdateOne<void, ServerUpdateCommand> {}
