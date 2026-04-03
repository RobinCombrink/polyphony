import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/domain_extensions/api_model_extensions.dart";
import "package:polyphony_flutter_client/shared/repositories/block_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/block_service.dart";

class BlockRepository implements BlockRepo {
  const BlockRepository({required BlockService blockService})
      : _blockService = blockService;

  final BlockService _blockService;

  @override
  Future<Result<void>> createOne({required BlockUserCommand command}) {
    return _blockService.blockUser(userId: command.userId.value);
  }

  @override
  Future<Result<void>> deleteOne({required UnblockUserCommand command}) {
    return _blockService.unblockUser(userId: command.userId.value);
  }

  @override
  Future<Result<Iterable<BlockedUser>>> getMany({
    required GetBlockedUsersQuery query,
  }) async {
    final serviceResult = await _blockService.listBlockedUsers();

    return switch (serviceResult) {
      Ok<List<ApiBlockedUser>>(:final value) => Ok<Iterable<BlockedUser>>(
          value.map((blockedUser) => blockedUser.toDomainModel()).toList()),
      Error<List<ApiBlockedUser>>(:final error) =>
        Error<Iterable<BlockedUser>>(error),
    };
  }
}
