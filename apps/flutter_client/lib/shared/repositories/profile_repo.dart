import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/repositories/repository_mixins.dart";

class GetProfileQuery {
  const GetProfileQuery();
}

class UpdateDisplayNameCommand {
  const UpdateDisplayNameCommand({
    required this.displayName,
  });

  final String displayName;
}

abstract interface class ProfileRepo
    with
        RepositoryGetOne<UserProfile, GetProfileQuery>,
        RepositoryUpdateOne<UserProfile, UpdateDisplayNameCommand> {}
