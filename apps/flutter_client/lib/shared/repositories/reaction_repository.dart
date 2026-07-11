import "package:polyphony_flutter_client/shared/repositories/reaction_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/reaction_service.dart";

class ReactionRepository implements ReactionRepo {
  const ReactionRepository({required ReactionService reactionService})
      : _reactionService = reactionService;

  final ReactionService _reactionService;

  @override
  Future<Result<Iterable<ReactionSummary>>> getMany({
    required ListReactionsQuery query,
  }) {
    return _reactionService.listReactions(
      channelId: query.channelId,
      messageId: query.messageId,
    );
  }

  @override
  Future<Result<void>> updateOne({
    required ToggleReactionCommand command,
  }) {
    return _reactionService.toggleReaction(
      channelId: command.channelId,
      messageId: command.messageId,
      emoteId: command.emoteId,
    );
  }
}
