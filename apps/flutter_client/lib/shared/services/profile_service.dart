import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

abstract interface class ProfileService {
  Future<Result<ApiMe>> getMe();

  Future<Result<ApiMe>> updateDisplayName({
    required String displayName,
  });

  Future<Result<ApiUserLookup>> getUserById({
    required String userId,
  });
}
