import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/repositories/repository_mixins.dart";

class GetServerMembersQuery {
  const GetServerMembersQuery({
    required this.serverId,
  });

  final String serverId;
}

abstract interface class ServerMemberRepo
    with RepositoryGetMany<ServerMember, GetServerMembersQuery> {}
