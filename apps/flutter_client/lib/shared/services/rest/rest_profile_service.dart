import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/cache/memory_cache.dart";
import "package:polyphony_flutter_client/shared/services/profile_service.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_request_service_base.dart";

class RestProfileService extends RestRequestServiceBase
    implements ProfileService {
  RestProfileService({
    required super.dio,
  });

  final _meCache = MemoryCache<ApiMe>(ttl: const Duration(minutes: 10));
  final _userCache =
      MemoryCache<ApiUserLookup>(ttl: const Duration(minutes: 10));

  @override
  Future<Result<ApiMe>> getMe() async {
    final cached = _meCache.get("me");
    if (cached != null) {
      return Ok<ApiMe>(cached);
    }

    final result = await performGetRequest<ApiMe>(
      endpoint: "/api/v1/me",
      operation: "get me",
      decodeItem: ApiMe.fromJson,
    );

    if (result case Ok<ApiMe>(:final value)) {
      _meCache.set("me", value);
    }

    return result;
  }

  @override
  Future<Result<ApiMe>> updateDisplayName({
    required String displayName,
  }) async {
    final result = await performPatchRequest<ApiMe>(
      endpoint: "/api/v1/me",
      operation: "update display name",
      body: <String, dynamic>{"display_name": displayName},
      expectedStatusCode: 200,
      decodeItem: ApiMe.fromJson,
    );

    if (result case Ok<ApiMe>()) {
      _meCache.invalidate("me");
    }

    return result;
  }

  @override
  Future<Result<ApiUserLookup>> getUserById({
    required String userId,
  }) async {
    final cacheKey = "user:$userId";
    final cached = _userCache.get(cacheKey);
    if (cached != null) {
      return Ok<ApiUserLookup>(cached);
    }

    final result = await performGetRequest<ApiUserLookup>(
      endpoint: "/api/v1/users/$userId",
      operation: "get user by id",
      decodeItem: ApiUserLookup.fromJson,
    );

    if (result case Ok<ApiUserLookup>(:final value)) {
      _userCache.set(cacheKey, value);
    }

    return result;
  }
}
