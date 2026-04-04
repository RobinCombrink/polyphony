import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/cache/memory_cache.dart";
import "package:polyphony_flutter_client/shared/services/pinned_message_service.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_request_service_base.dart";

class RestPinnedMessageService extends RestRequestServiceBase
    implements PinnedMessageService {
  RestPinnedMessageService({required super.dio});

  final _cache = MemoryCache<List<PinnedMessage>>();

  @override
  Future<Result<void>> pinMessage({
    required ServerId serverId,
    required MessageId messageId,
  }) async {
    final result = await performPostRequestWithoutResponseBody(
      endpoint: "/api/v1/servers/${serverId.value}/pins",
      operation: "pin message",
      body: {"message_id": messageId.value},
      expectedStatusCode: 200,
    );

    if (result case Ok<void>()) {
      _cache.invalidate("pins:${serverId.value}");
    }

    return result;
  }

  @override
  Future<Result<void>> unpinMessage({
    required ServerId serverId,
    required MessageId messageId,
  }) async {
    final result = await performDeleteRequest(
      endpoint: "/api/v1/servers/${serverId.value}/pins/${messageId.value}",
      operation: "unpin message",
      expectedStatusCode: 200,
    );

    if (result case Ok<void>()) {
      _cache.invalidate("pins:${serverId.value}");
    }

    return result;
  }

  @override
  Future<Result<List<PinnedMessage>>> listPinnedMessages({
    required ServerId serverId,
  }) async {
    final cacheKey = "pins:${serverId.value}";
    final cached = _cache.get(cacheKey);
    if (cached != null) {
      return Ok<List<PinnedMessage>>(cached);
    }

    final result = await performListRequest<PinnedMessage>(
      endpoint: "/api/v1/servers/${serverId.value}/pins",
      operation: "list pinned messages",
      decodeItem: (json) => PinnedMessage(
        id: json["id"] as String,
        serverId: ServerId(json["server_id"] as String),
        channelId: ChannelId(json["channel_id"] as String),
        messageId: MessageId(json["message_id"] as String),
        pinnedByUserId: UserId(json["pinned_by_user_id"] as String),
        content: json["content"] as String,
        authorUserId: UserId(json["author_user_id"] as String),
      ),
    );

    if (result case Ok<List<PinnedMessage>>(:final value)) {
      _cache.set(cacheKey, value);
    }

    return result;
  }
}
