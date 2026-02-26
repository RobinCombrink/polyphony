import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

abstract interface class ServerService {
  Future<Result<List<ApiServer>>> listServers({
    required String baseUrl,
  });

  Future<Result<ApiServer>> createServer({
    required String baseUrl,
    required String name,
  });

  Future<Result<void>> addServerMember({
    required String baseUrl,
    required String serverId,
    required String userSubject,
  });
}
