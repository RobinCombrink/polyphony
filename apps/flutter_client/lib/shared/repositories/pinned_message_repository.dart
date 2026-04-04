import "package:polyphony_flutter_client/shared/repositories/pinned_message_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/pinned_message_service.dart";

class PinnedMessageRepository implements PinnedMessageRepo {
  const PinnedMessageRepository({
    required PinnedMessageService pinnedMessageService,
  }) : _pinnedMessageService = pinnedMessageService;

  final PinnedMessageService _pinnedMessageService;

  @override
  Future<Result<Iterable<PinnedMessage>>> getMany({
    required ListPinnedMessagesQuery query,
  }) {
    return _pinnedMessageService.listPinnedMessages(
      serverId: query.serverId,
    );
  }

  @override
  Future<Result<void>> createOne({required PinMessageCommand command}) {
    return _pinnedMessageService.pinMessage(
      serverId: command.serverId,
      messageId: command.messageId,
    );
  }

  @override
  Future<Result<void>> deleteOne({required UnpinMessageCommand command}) {
    return _pinnedMessageService.unpinMessage(
      serverId: command.serverId,
      messageId: command.messageId,
    );
  }
}
