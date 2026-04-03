import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/domain_extensions/api_model_extensions.dart";
import "package:polyphony_flutter_client/shared/repositories/friend_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/friend_service.dart";

class FriendRepository implements FriendRepo {
  const FriendRepository({required FriendService friendService})
      : _friendService = friendService;

  final FriendService _friendService;

  @override
  Future<Result<Iterable<Friend>>> getMany({
    required GetFriendsQuery query,
  }) async {
    final serviceResult = await _friendService.listFriends();

    return switch (serviceResult) {
      Ok<List<ApiFriend>>(:final value) => Ok<Iterable<Friend>>(
          value.map((friend) => friend.toDomainModel()).toList()),
      Error<List<ApiFriend>>(:final error) => Error<Iterable<Friend>>(error),
    };
  }

  @override
  Future<Result<Iterable<PendingFriendRequest>>> getOne({
    required GetOutgoingPendingFriendRequestsQuery query,
  }) async {
    final serviceResult =
        await _friendService.listOutgoingPendingFriendRequests();

    return switch (serviceResult) {
      Ok<List<ApiFriendRequest>>(:final value) =>
        Ok<Iterable<PendingFriendRequest>>(
            value.map((request) => request.toDomainModel()).toList()),
      Error<List<ApiFriendRequest>>(:final error) =>
        Error<Iterable<PendingFriendRequest>>(error),
    };
  }

  @override
  Future<Result<PendingFriendRequest>> createOne({
    required SendFriendRequestFromServerContextCommand command,
  }) async {
    final serviceResult =
        await _friendService.sendFriendRequestFromServerContext(
      serverId: command.serverId.value,
      targetUserId: command.targetUserId.value,
    );

    return switch (serviceResult) {
      Ok<ApiFriendRequest>(:final value) =>
        Ok<PendingFriendRequest>(value.toDomainModel()),
      Error<ApiFriendRequest>(:final error) =>
        Error<PendingFriendRequest>(error),
    };
  }

  @override
  Future<Result<void>> deleteOne({
    required CancelOutgoingFriendRequestCommand command,
  }) {
    return _friendService.cancelOutgoingFriendRequest(
      friendRequestId: command.friendRequestId.value,
    );
  }
}
