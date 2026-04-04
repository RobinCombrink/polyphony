import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

class ReactionSummary {
  const ReactionSummary({
    required this.emoteId,
    required this.count,
    required this.reactedByCurrentUser,
  });

  final String emoteId;
  final int count;
  final bool reactedByCurrentUser;
}

abstract interface class ReactionService {
  Future<Result<void>> toggleReaction({
    required ChannelId channelId,
    required MessageId messageId,
    required String emoteId,
  });

  Future<Result<List<ReactionSummary>>> listReactions({
    required ChannelId channelId,
    required MessageId messageId,
  });
}
