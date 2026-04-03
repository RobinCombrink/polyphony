import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/repositories/repository_mixins.dart";

class GetFriendsQuery {
  const GetFriendsQuery();
}

class GetOutgoingPendingFriendRequestsQuery {
  const GetOutgoingPendingFriendRequestsQuery();
}

class SendFriendRequestFromServerContextCommand {
  const SendFriendRequestFromServerContextCommand({
    required this.serverId,
    required this.targetUserId,
  });

  final ServerId serverId;
  final UserId targetUserId;
}

class CancelOutgoingFriendRequestCommand {
  const CancelOutgoingFriendRequestCommand({
    required this.friendRequestId,
  });

  final FriendRequestId friendRequestId;
}

abstract interface class FriendRepo
    with
        RepositoryGetMany<Friend, GetFriendsQuery>,
        RepositoryGetOne<Iterable<PendingFriendRequest>,
            GetOutgoingPendingFriendRequestsQuery>,
        RepositoryCreateOne<PendingFriendRequest,
            SendFriendRequestFromServerContextCommand>,
        RepositoryDeleteOne<CancelOutgoingFriendRequestCommand> {}
