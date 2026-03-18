import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/block_service.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_request_service_base.dart";

class RestBlockService extends RestRequestServiceBase implements BlockService {
  RestBlockService({
    required super.dio,
  });

  @override
  Future<Result<void>> blockUser({required String userId}) {
    return performPostRequestWithoutResponseBody(
      endpoint: "/api/v1/blocks/$userId",
      operation: "block user",
      body: const <String, dynamic>{},
      expectedStatusCode: 201,
    );
  }

  @override
  Future<Result<List<ApiBlockedUser>>> listBlockedUsers() {
    return performListRequest<ApiBlockedUser>(
      endpoint: "/api/v1/blocks",
      operation: "list blocked users",
      decodeItem: ApiBlockedUser.fromJson,
    );
  }

  @override
  Future<Result<void>> unblockUser({required String userId}) {
    return performDeleteRequest(
      endpoint: "/api/v1/blocks/$userId",
      operation: "unblock user",
      expectedStatusCode: 204,
    );
  }
}
