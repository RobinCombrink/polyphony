import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/repositories/repository_mixins.dart";

class GetFriendsQuery {
  const GetFriendsQuery();
}

class SendFriendRequestFromServerContextCommand {
  const SendFriendRequestFromServerContextCommand({
    required this.serverId,
    required this.targetUserId,
  });

  final String serverId;
  final String targetUserId;
}

abstract interface class FriendRepo
    with
        RepositoryGetMany<Friend, GetFriendsQuery>,
        RepositoryCreateOne<void, SendFriendRequestFromServerContextCommand> {}
