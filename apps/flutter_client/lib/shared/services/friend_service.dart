import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

abstract interface class FriendService {
  Future<Result<List<ApiFriend>>> listFriends();

  Future<Result<List<ApiFriendRequest>>> listOutgoingPendingFriendRequests();

  Future<Result<ApiFriendRequest>> sendFriendRequestFromServerContext({
    required String serverId,
    required String targetUserId,
  });

  Future<Result<void>> cancelOutgoingFriendRequest({
    required String friendRequestId,
  });
}
