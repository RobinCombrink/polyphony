import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/friend_service.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_request_service_base.dart";

class RestFriendService extends RestRequestServiceBase
    implements FriendService {
  RestFriendService({
    required super.dio,
  });

  @override
  Future<Result<List<ApiFriend>>> listFriends() {
    return performListRequest<ApiFriend>(
      endpoint: "/api/v1/friends",
      operation: "list friends",
      decodeItem: ApiFriend.fromJson,
    );
  }

  @override
  Future<Result<List<ApiFriendRequest>>> listOutgoingPendingFriendRequests() {
    return performListRequest<ApiFriendRequest>(
      endpoint: "/api/v1/friends/requests/outgoing",
      operation: "list outgoing pending friend requests",
      decodeItem: ApiFriendRequest.fromJson,
    );
  }

  @override
  Future<Result<ApiFriendRequest>> sendFriendRequestFromServerContext({
    required String serverId,
    required String targetUserId,
  }) {
    return performPostRequest<ApiFriendRequest>(
      endpoint: "/api/v1/servers/$serverId/friends/requests/$targetUserId",
      operation: "send friend request from server context",
      body: const <String, dynamic>{},
      expectedStatusCode: 201,
      decodeItem: ApiFriendRequest.fromJson,
    );
  }

  @override
  Future<Result<void>> cancelOutgoingFriendRequest({
    required String friendRequestId,
  }) {
    return performPostRequestWithoutResponseBody(
      endpoint: "/api/v1/friends/requests/$friendRequestId/cancel",
      operation: "cancel outgoing friend request",
      body: const <String, dynamic>{},
      expectedStatusCode: 200,
    );
  }
}
