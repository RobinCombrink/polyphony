import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

abstract interface class ProfileRepo {
  Future<Result<UserProfile>> getMe({
    required String baseUrl,
  });

  Future<Result<UserProfile>> updateDisplayName({
    required String baseUrl,
    required String displayName,
  });
}
