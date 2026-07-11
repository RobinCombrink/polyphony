import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/repositories/reaction_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

class ToggleReactionUseCase {
  const ToggleReactionUseCase({required ReactionRepo reactionRepo})
      : _reactionRepo = reactionRepo;

  final ReactionRepo _reactionRepo;

  Future<Result<void>> call({
    required ChannelId channelId,
    required MessageId messageId,
    required String emoteId,
  }) {
    return _reactionRepo.updateOne(
      command: ToggleReactionCommand(
        channelId: channelId,
        messageId: messageId,
        emoteId: emoteId,
      ),
    );
  }
}
