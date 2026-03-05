import "package:polyphony_flutter_client/shared/config/polyphony_config.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/chat_api.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/server_service.dart";

class RestServerService implements ServerService {
  const RestServerService({
    required ChatApi chatApi,
  }) : _chatApi = chatApi;

  final ChatApi _chatApi;
  final String _baseUrl = PolyphonyConfig.backendBaseUrl;

  @override
  Future<Result<List<ApiServer>>> listServers() {
    return _chatApi.listServers(baseUrl: _baseUrl);
  }

  @override
  Future<Result<ApiServer>> createServer({
    required String name,
  }) {
    return _chatApi.createServer(baseUrl: _baseUrl, name: name);
  }

  @override
  Future<Result<void>> deleteServer({
    required String serverId,
  }) {
    return _chatApi.deleteServer(
      baseUrl: _baseUrl,
      serverId: serverId,
    );
  }

  @override
  Future<Result<void>> addServerMember({
    required String serverId,
    required String userId,
  }) {
    return _chatApi.addServerMember(
      baseUrl: _baseUrl,
      serverId: serverId,
      userId: userId,
    );
  }

  @override
  Future<Result<List<ApiServerMember>>> listServerMembers({
    required String serverId,
  }) {
    return _chatApi.listServerMembers(
      baseUrl: _baseUrl,
      serverId: serverId,
    );
  }
}
