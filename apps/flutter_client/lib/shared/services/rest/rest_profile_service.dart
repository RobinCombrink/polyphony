import "package:polyphony_flutter_client/shared/config/polyphony_config.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/chat_api.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/profile_service.dart";

class RestProfileService implements ProfileService {
  const RestProfileService({
    required ChatApi chatApi,
  }) : _chatApi = chatApi;

  final ChatApi _chatApi;
  final String _baseUrl = PolyphonyConfig.backendBaseUrl;

  @override
  Future<Result<ApiMe>> getMe() {
    return _chatApi.getMe(baseUrl: _baseUrl);
  }

  @override
  Future<Result<ApiMe>> updateDisplayName({
    required String displayName,
  }) {
    return _chatApi.updateDisplayName(
      baseUrl: _baseUrl,
      displayName: displayName,
    );
  }

  @override
  Future<Result<ApiUserLookup>> getUserById({
    required String userId,
  }) {
    return _chatApi.getUserById(
      baseUrl: _baseUrl,
      userId: userId,
    );
  }
}
