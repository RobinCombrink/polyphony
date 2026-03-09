import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/profile_service.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_request_service_base.dart";

class RestProfileService extends RestRequestServiceBase
    implements ProfileService {
  RestProfileService({
    required super.dio,
  });

  @override
  Future<Result<ApiMe>> getMe() {
    return performGetRequest<ApiMe>(
      endpoint: "/api/v1/me",
      operation: "get me",
      decodeItem: ApiMe.fromJson,
    );
  }

  @override
  Future<Result<ApiMe>> updateDisplayName({
    required String displayName,
  }) {
    return performPatchRequest<ApiMe>(
      endpoint: "/api/v1/me",
      operation: "update display name",
      body: <String, dynamic>{"display_name": displayName},
      expectedStatusCode: 200,
      decodeItem: ApiMe.fromJson,
    );
  }

  @override
  Future<Result<ApiUserLookup>> getUserById({
    required String userId,
  }) {
    return performGetRequest<ApiUserLookup>(
      endpoint: "/api/v1/users/$userId",
      operation: "get user by id",
      decodeItem: ApiUserLookup.fromJson,
    );
  }
}
