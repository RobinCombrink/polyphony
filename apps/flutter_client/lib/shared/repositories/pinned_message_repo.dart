import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/repositories/repository_mixins.dart";
import "package:polyphony_flutter_client/shared/services/pinned_message_service.dart";

class ListPinnedMessagesQuery {
  const ListPinnedMessagesQuery({required this.serverId});

  final ServerId serverId;
}

class PinMessageCommand {
  const PinMessageCommand({
    required this.serverId,
    required this.messageId,
  });

  final ServerId serverId;
  final MessageId messageId;
}

class UnpinMessageCommand {
  const UnpinMessageCommand({
    required this.serverId,
    required this.messageId,
  });

  final ServerId serverId;
  final MessageId messageId;
}

abstract interface class PinnedMessageRepo
    with
        RepositoryGetMany<PinnedMessage, ListPinnedMessagesQuery>,
        RepositoryCreateOne<void, PinMessageCommand>,
        RepositoryDeleteOne<UnpinMessageCommand> {}
