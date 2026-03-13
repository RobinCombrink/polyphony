import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

abstract interface class ServerService {
  Future<Result<List<ApiServer>>> listServers();

  Future<Result<ApiServer>> createServer({
    required String name,
  });

  Future<Result<void>> deleteServer({
    required String serverId,
  });

  Future<Result<void>> addServerMember({
    required String serverId,
    required String userId,
  });

  Future<Result<void>> inviteFriendToServer({
    required String serverId,
    required String friendUserId,
  });

  Future<Result<List<ApiServerMember>>> listServerMembers({
    required String serverId,
  });
}
