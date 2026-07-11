import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/models/reaction_summary.dart";
import "package:polyphony_flutter_client/shared/repositories/repository_mixins.dart";

class ListReactionsQuery {
  const ListReactionsQuery({
    required this.channelId,
    required this.messageId,
  });

  final ChannelId channelId;
  final MessageId messageId;
}

class ToggleReactionCommand {
  const ToggleReactionCommand({
    required this.channelId,
    required this.messageId,
    required this.emoteId,
  });

  final ChannelId channelId;
  final MessageId messageId;
  final String emoteId;
}

abstract interface class ReactionRepo
    with
        RepositoryGetMany<ReactionSummary, ListReactionsQuery>,
        RepositoryUpdateOne<void, ToggleReactionCommand> {}
