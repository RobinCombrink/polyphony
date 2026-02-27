import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/repositories/repository_mixins.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

class GetProfileQuery {
  const GetProfileQuery();
}

class GetUserProfileByIdQuery {
  const GetUserProfileByIdQuery({
    required this.userId,
  });

  final String userId;
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
        RepositoryUpdateOne<UserProfile, UpdateDisplayNameCommand> {
  Future<Result<UserProfile>> getUserById({
    required GetUserProfileByIdQuery query,
  });
}
