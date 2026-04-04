import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

class PinnedMessage {
  const PinnedMessage({
    required this.id,
    required this.serverId,
    required this.channelId,
    required this.messageId,
    required this.pinnedByUserId,
    required this.content,
    required this.authorUserId,
  });

  final String id;
  final ServerId serverId;
  final ChannelId channelId;
  final MessageId messageId;
  final UserId pinnedByUserId;
  final String content;
  final UserId authorUserId;
}

abstract interface class PinnedMessageService {
  Future<Result<void>> pinMessage({
    required ServerId serverId,
    required MessageId messageId,
  });

  Future<Result<void>> unpinMessage({
    required ServerId serverId,
    required MessageId messageId,
  });

  Future<Result<List<PinnedMessage>>> listPinnedMessages({
    required ServerId serverId,
  });
}
