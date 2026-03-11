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
  Future<Result<void>> createOne({
    required SendFriendRequestFromServerContextCommand command,
  }) {
    return _friendService.sendFriendRequestFromServerContext(
      serverId: command.serverId,
      targetUserId: command.targetUserId,
    );
  }
}
