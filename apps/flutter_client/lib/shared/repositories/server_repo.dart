import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/repositories/repository_mixins.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

class GetServersQuery {
  const GetServersQuery();
}

class GetServerMembersQuery {
  const GetServerMembersQuery({
    required this.serverId,
  });

  final String serverId;
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

  final String serverId;
}

class AddServerMemberCommand {
  const AddServerMemberCommand({
    required this.serverId,
    required this.userId,
  });

  final String serverId;
  final String userId;
}

abstract interface class ServerRepo
    with
        RepositoryGetMany<Server, GetServersQuery>,
        RepositoryCreateOne<Server, CreateServerCommand>,
        RepositoryDeleteOne<DeleteServerCommand>,
        RepositoryUpdateOne<void, AddServerMemberCommand> {
  Future<Result<Iterable<ServerMember>>> getServerMembers({
    required GetServerMembersQuery query,
  });
}
