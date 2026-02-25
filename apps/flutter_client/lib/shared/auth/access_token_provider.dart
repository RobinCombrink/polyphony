import "package:polyphony_flutter_client/shared/result/result.dart";

abstract interface class AccessTokenProvider {
  Future<Result<String>> getAccessToken();
}
