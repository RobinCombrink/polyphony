import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/models/reaction_summary.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

export "package:polyphony_flutter_client/shared/models/reaction_summary.dart";

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
