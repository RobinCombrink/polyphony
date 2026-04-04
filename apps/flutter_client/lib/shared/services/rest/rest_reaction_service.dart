import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/reaction_service.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_request_service_base.dart";

class RestReactionService extends RestRequestServiceBase
    implements ReactionService {
  RestReactionService({required super.dio});

  @override
  Future<Result<void>> toggleReaction({
    required ChannelId channelId,
    required MessageId messageId,
    required String emoteId,
  }) {
    return performPostRequestWithoutResponseBody(
      endpoint:
          "/api/v1/channels/${channelId.value}/messages/${messageId.value}/reactions",
      operation: "toggle reaction",
      body: {"emote_id": emoteId},
      expectedStatusCode: 200,
    );
  }

  @override
  Future<Result<List<ReactionSummary>>> listReactions({
    required ChannelId channelId,
    required MessageId messageId,
  }) {
    return performListRequest<ReactionSummary>(
      endpoint:
          "/api/v1/channels/${channelId.value}/messages/${messageId.value}/reactions",
      operation: "list reactions",
      decodeItem: (json) => ReactionSummary(
        emoteId: json["emote_id"] as String,
        count: json["count"] as int,
        reactedByCurrentUser: json["reacted_by_current_user"] as bool,
      ),
    );
  }
}
