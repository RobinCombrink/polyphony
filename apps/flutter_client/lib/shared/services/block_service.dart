import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

abstract interface class BlockService {
  Future<Result<List<ApiBlockedUser>>> listBlockedUsers();

  Future<Result<void>> blockUser({
    required String userId,
  });

  Future<Result<void>> unblockUser({
    required String userId,
  });
}
