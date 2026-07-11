import "package:polyphony_flutter_client/shared/models/entity_ids.dart";

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
