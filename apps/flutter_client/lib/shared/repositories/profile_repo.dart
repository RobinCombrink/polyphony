import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/repositories/repository_mixins.dart";

class GetUserQuery {
  const GetUserQuery({
    required this.userId,
  });

  final UserId userId;
}

class UpdateDisplayNameCommand {
  const UpdateDisplayNameCommand({
    required this.displayName,
  });

  final String displayName;
}

abstract interface class ProfileRepo
    with
        RepositoryGetOne<UserProfile, GetUserQuery>,
        RepositoryUpdateOne<UserProfile, UpdateDisplayNameCommand> {}
