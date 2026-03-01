import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

abstract interface class TextSessionService {
  Future<Result<ApiTextConnectSession>> connectTextSession({
    required String channelId,
  });
}
