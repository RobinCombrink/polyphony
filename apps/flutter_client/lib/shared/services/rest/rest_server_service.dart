import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_request_service_base.dart";
import "package:polyphony_flutter_client/shared/services/server_service.dart";

class RestServerService extends RestRequestServiceBase
    implements ServerService {
  RestServerService({
    required super.dio,
  });

  @override
  Future<Result<List<ApiServer>>> listServers() {
    return performListRequest<ApiServer>(
      endpoint: "/api/v1/servers",
      operation: "list servers",
      decodeItem: ApiServer.fromJson,
    );
  }

  @override
  Future<Result<ApiServer>> createServer({
    required String name,
  }) {
    return performPostRequest<ApiServer>(
      endpoint: "/api/v1/servers",
      operation: "create server",
      body: <String, dynamic>{"name": name},
      expectedStatusCode: 201,
      decodeItem: ApiServer.fromJson,
    );
  }

  @override
  Future<Result<void>> deleteServer({
    required String serverId,
  }) {
    return performDeleteRequest(
      endpoint: "/api/v1/servers/$serverId",
      operation: "delete server",
      expectedStatusCode: 204,
    );
  }

  @override
  Future<Result<void>> updateServerName({
    required String serverId,
    required String name,
  }) {
    return performPatchRequestWithoutResponseBody(
      endpoint: "/api/v1/servers/$serverId",
      operation: "update server name",
      body: <String, dynamic>{"name": name},
      expectedStatusCode: 204,
    );
  }

  @override
  Future<Result<void>> addServerMember({
    required String serverId,
    required String userId,
  }) {
    return performPostRequestWithoutResponseBody(
      endpoint: "/api/v1/servers/$serverId/members",
      operation: "add server member",
      body: <String, dynamic>{"user_id": userId},
      expectedStatusCode: 201,
    );
  }

  @override
  Future<Result<void>> inviteFriendToServer({
    required String serverId,
    required String friendUserId,
  }) {
    return performPostRequestWithoutResponseBody(
      endpoint: "/api/v1/servers/$serverId/invite/friends/$friendUserId",
      operation: "invite friend to server",
      body: const <String, dynamic>{},
      expectedStatusCode: 201,
    );
  }

  @override
  Future<Result<List<ApiServerMember>>> listServerMembers({
    required String serverId,
  }) {
    return performListRequest<ApiServerMember>(
      endpoint: "/api/v1/servers/$serverId/members",
      operation: "list server members",
      decodeItem: ApiServerMember.fromJson,
    );
  }
}
