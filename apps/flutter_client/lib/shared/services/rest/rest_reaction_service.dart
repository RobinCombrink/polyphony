import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/cache/memory_cache.dart";
import "package:polyphony_flutter_client/shared/services/reaction_service.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_request_service_base.dart";

class RestReactionService extends RestRequestServiceBase
    implements ReactionService {
  RestReactionService({required super.dio});

  final _cache =
      MemoryCache<List<ReactionSummary>>(ttl: const Duration(minutes: 2));

  @override
  Future<Result<void>> toggleReaction({
    required ChannelId channelId,
    required MessageId messageId,
    required String emoteId,
  }) async {
    final result = await performPostRequestWithoutResponseBody(
      endpoint:
          "/api/v1/channels/${channelId.value}/messages/${messageId.value}/reactions",
      operation: "toggle reaction",
      body: {"emote_id": emoteId},
      expectedStatusCode: 200,
    );

    if (result case Ok<void>()) {
      _cache.invalidate(
        "reactions:${channelId.value}:${messageId.value}",
      );
    }

    return result;
  }

  @override
  Future<Result<List<ReactionSummary>>> listReactions({
    required ChannelId channelId,
    required MessageId messageId,
  }) async {
    final cacheKey = "reactions:${channelId.value}:${messageId.value}";
    final cached = _cache.get(cacheKey);
    if (cached != null) {
      return Ok<List<ReactionSummary>>(cached);
    }

    final result = await performListRequest<ReactionSummary>(
      endpoint:
          "/api/v1/channels/${channelId.value}/messages/${messageId.value}/reactions",
      operation: "list reactions",
      decodeItem: (json) => ReactionSummary(
        emoteId: json["emote_id"] as String,
        count: json["count"] as int,
        reactedByCurrentUser: json["reacted_by_current_user"] as bool,
      ),
    );

    if (result case Ok<List<ReactionSummary>>(:final value)) {
      _cache.set(cacheKey, value);
    }

    return result;
  }
}
