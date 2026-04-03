import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/repositories/repository_mixins.dart";

class GetBlockedUsersQuery {
  const GetBlockedUsersQuery();
}

class BlockUserCommand {
  const BlockUserCommand({required this.userId});

  final UserId userId;
}

class UnblockUserCommand {
  const UnblockUserCommand({required this.userId});

  final UserId userId;
}

abstract interface class BlockRepo
    with
        RepositoryGetMany<BlockedUser, GetBlockedUsersQuery>,
        RepositoryCreateOne<void, BlockUserCommand>,
        RepositoryDeleteOne<UnblockUserCommand> {}
